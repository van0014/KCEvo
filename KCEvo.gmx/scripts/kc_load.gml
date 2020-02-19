//kc_load script, by van0014. Rewritten 02/2020

//Check if the file exists
if !(file_exists(argument0)){return -1; exit}

//Open the map and begin checking it
kcb = file_bin_open(argument0,0);
sze = file_bin_size(kcb);

//Minimum map size. $13F has no blocks, enemies or background data.
if (sze < $13F)
{
	//Close the file
	file_bin_close(kcb);

	//Show errors if arg1 == 1
	if (argument1 == 1)
	{
		show_message("Map is too small ($"+dec_hex(sze)+"). Sorry, but I won't try to load it. It's probably a broken map");
	}
	return -1;
	exit;
}

//Check file header to see if it's a valid map
hdrv = "";
hdrv = (file_bin_read_byte(kcb) << 24) + (file_bin_read_byte(kcb) << 16) + (file_bin_read_byte(kcb) << 8) + file_bin_read_byte(kcb);

if (hdrv != $4B4D4150)
{
	//Close the file
	file_bin_close(kcb);
	
	//Show errors if arg1 == 1
	if (argument1 == 1)
	{
		show_message("Map header isn't 'KMAP'. It's $"+dec_hex(hdrv)+". Sorry, but I won't try to load this file in case it's not actually a map");
	}
	return -1;
	exit;
}

//Copy map to RAM
ds_list_clear(global.kcm);

file_bin_seek(kcb,0);
for (i=0; i<sze; i+=1)
{
	ds_list_add(global.kcm,file_bin_read_byte(kcb));
}
file_bin_close(kcb);

//Basic checksare done. Now, time to start loading the map

//Get map size (Saved in screens. 20x14 tiles per screen)
global.scr = ds_list_find_value(global.kcm,$6) * (ds_list_find_value(global.kcm,$7) & $3F);
global.mx = ((ds_list_find_value(global.kcm,$6)) * 20);
global.my = ((ds_list_find_value(global.kcm,$7) & $3F) * 14);

//Clear the tile memory from RAM, then allocate enough to fit this map
ds_grid_clear(global.level,0);
ds_grid_resize(global.level,global.mx,global.my);

//map size in pixels
global.xl = global.mx*16;
global.yl = global.my*16;

//Warn if screens exceeds 30
if (global.scr > 30) and (argument1 == 1)
{
	show_message("Warning! Map is larger than 30 screens (it's "+global.scr+" screens). It may not import or play properly");
}

//Theme bytes. Remember to mask when using. $0F for the theme. $F0 is for lava/storm/hail
global.thmf = ds_list_find_value(global.kcm,$8);
global.thmb = ds_list_find_value(global.kcm,$9);

//Kid and flag pos
global.kidx = (ds_list_find_value(global.kcm,$B) << 8) + ds_list_find_value(global.kcm,$A);
global.kidy = (ds_list_find_value(global.kcm,$D) << 8) + ds_list_find_value(global.kcm,$C);
global.flagx = (ds_list_find_value(global.kcm,$F) << 8) + ds_list_find_value(global.kcm,$E);
global.flagy = (ds_list_find_value(global.kcm,$11) << 8) + ds_list_find_value(global.kcm,$10);

//Store file data addresses
addr_tile = (ds_list_find_value(global.kcm,$13) << 8) + ds_list_find_value(global.kcm,$12);
addr_block = (ds_list_find_value(global.kcm,$15) << 8) + ds_list_find_value(global.kcm,$14);
addr_backgnd = (ds_list_find_value(global.kcm,$17) << 8) + ds_list_find_value(global.kcm,$16);
addr_enemy = (ds_list_find_value(global.kcm,$19) << 8) + ds_list_find_value(global.kcm,$18);
addr_eof = (ds_list_find_value(global.kcm,$1B) << 8) + ds_list_find_value(global.kcm,$1A);

//if (addr_eof <= sze) and (addr_enemy < addr_eof) and (addr_backgnd < addr_enemy) and (addr_block < addr_tile)
if (addr_eof > sze)
{
	show_message("Warning: End of file address is bigger than the file size");
}

if (addr_enemy > sze)
{
	show_message("The enemy header saved in this map points past the end of the file. ");
}

//Check if tile address seems valid. It should be smallest, and smaller than total file size
if (addr_tile  + (global.mx * global.my) > min(addr_block,addr_backgnd,addr_enemy,addr_eof,sze))
{
	if ($1C  + (global.mx * global.my) >= sze)
	{
		show_message("There's a problem with this map. The map Width x Height is bigger than the file size. Please check it in a hex editor. ##Bytes $6 and $7 are map Width and Height in 'screens'. Use (W * 320) and (H * 224) to get size in pixels. Height is bitmasked with $3F first");
	}
	show_message("Warning: Tile data address ($" + dec_hex(addr_tile) + ")overlaps another address. I'll try to load your map anyway");
	//Try to load tiles anyway
	addr_tile = $1C;
}

//Clear previously loaded map data
kc_prep_load();
	
//Set theme art
switch ((global.thmf & $F))
	{
		case 1:
		global.spr_tile = spr_sky;
		break;
		case 2:
		global.spr_tile = spr_ice;
		break;
		case 3:
		global.spr_tile = spr_hills;
		break;
		case 4:
		global.spr_tile = spr_island;
		break;
		case 5:
		global.spr_tile = spr_desert;
		break;
		case 6:
		global.spr_tile = spr_swamp;
		break;
		case 7:
		global.spr_tile = spr_mountain;
		break;
		case 8:
		global.spr_tile = spr_cave;
		break;
		case 9:
		global.spr_tile = spr_woods;
		break;
		case 10:
		global.spr_tile = spr_city;
		break;
	}

//Make a surface, to save as a sprite
tlc = surface_create((global.mx * 16),(global.my * 16));
//Change drawing target. No more drawing to the screen for this part. It happens in video memory instead
surface_set_target(tlc);
//Clear the surface to transparentwhite
draw_clear_alpha(c_white,0);
//Load tiles into RAM, in a ds_grid that's easy to manipulate arrays with
for (vy = 0; vy < global.my; vy += 2)
{
	for (vx = 0; vx < global.mx; vx += 2)
	{
		//Draw background contrast, for easyer tile alignment
		draw_set_color(c_white);
		//TL
		draw_rectangle(vx * 16,vy * 16,(vx * 16) + 16,(vy * 16) + 16,0);
		//Br
		draw_rectangle((vx * 16) + 16,(vy * 16) + 16,(vx * 16) + 32,(vy * 16) + 32,0);
		draw_set_color(make_color_rgb(245,245,245));
		//Tr
		draw_rectangle((vx * 16) + 16,vy * 16,(vx * 16) + 32,(vy * 16) + 16,0);
		//Bl
		draw_rectangle((vx * 16),(vy * 16) + 16,(vx * 16) + 16,(vy * 16) + 32,0);
	}
}

//Make a surface, to save as a sprite
tls = surface_create((global.mx * 16),(global.my * 16));

//Change drawing target. No more drawing to the screen for this part. It happens in video memory instead
surface_set_target(tls);
//Clear the surface to transparentwhite
draw_clear_alpha(c_white,0);

if (surface_exists(tlc))
{
	draw_surface(tlc,0,0);
}

//Load tiles into RAM, in a ds_grid that's easy to manipulate arrays with
for (vy = 0; vy < global.my; vy += 1)
{
	for (vx = 0; vx < global.mx; vx += 1)
	{
		ds_grid_set(global.level,vx,vy,ds_list_find_value(global.kcm,addr_tile + (vx + (global.mx * vy))));
		grx = ds_list_find_value(global.kcm,addr_tile + (vx + (global.mx * vy))) & $F;
		gry = (ds_list_find_value(global.kcm,addr_tile + (vx + (global.mx * vy))) & $F0) >> 4;
		//Draw background contrast, for easyer tile alignment
		//draw_sprite_part_ext(spr_slvl,0,((vx mod 2) * 16),((vy mod 2) * 16),16,16,(vx * 16),(vy * 16),1,1,c_white,1);
		//Draw the right part of the tileset, in the right place. Drawing target is on a surface, so you can't see it yet
		draw_sprite_part_ext(global.spr_tile,0,(grx * 16),(gry * 16),16,16,(vx * 16),(vy * 16),1,1,c_white,1);
	}
}

//Restore the drawing target, so we can draw to the screen and see what's going on again
surface_reset_target();

//Try to prevent a memory leak, and also try not to delete spr_none
if (sprite_exists(global.spr_lvl)) and (global.spr_lvl != spr_none)//0)
{
	sprite_delete(global.spr_lvl); 
	//global.lvl = 0;
}

//Make the sprite
global.spr_lvl = sprite_create_from_surface(tls,0,0,(global.mx*16),(global.my*16),0,0,0,0);

//Check if block address seems valid, based on current position in file. If there's a potential error with it, ask the question whether to load the map anyway
if ((addr_tile + (global.mx * global.my)) != addr_block) 
{
	if (!show_question("Warning: Block data offset ($" + dec_hex(addr_block) + ") isn't immediately after tiles ($" + dec_hex((addr_tile + ((global.mx * global.my)))) + "). Try to load the map anyway?"))
	{
		exit;
	}
	else
	{
		//Give the user the choice of using an auto generated block data address
		if (!show_question("Use the map's block data address? Clicking 'No' will try to read block data starting from the end of tile data ($" + dec_hex(addr_tile + (global.mx * global.my)) + ")"))
		{
		//Try to load blocks anyway
		addr_block = addr_tile + (global.mx * global.my);
		}
	}
}

//Window caption
room_caption = "KCEvo - " + filename_name(argument0);
global.sstr = "";
//This map is probably valid (made it to the end of the script). Update global.file
global.file = argument0;