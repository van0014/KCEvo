/*
**  Usage:
**      hex_to_dec(hex)
**
**  Arguments:
**      hex     a string of hexadecimal digits, four bits per character
**
**  Returns:
**      a non-negative integer
**
**  GMLscripts.com
*/
{
    var qhex,qdec,qh,qp;
    qhex = string_upper(argument0);
    qdec = 0;
    qh = "0123456789ABCDEF";
    for (qp=1;qp<=string_length(qhex);qp+=1) {
        qdec = qdec << 4 | (string_pos(string_char_at(qhex,qp),qh)-1);
    }
    return qdec;
}
