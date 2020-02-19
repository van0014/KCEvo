/*
**  Usage:
**      dec_to_hex(dec)
**
**  Arguments:
**      dec     a non-negative integer
**
**  Returns:
**      a string of hexadecimal digits, four bits per character
**
**  GMLscripts.com
*/
{
    var qdec,qhex,qh,qbyte,qhi,qlo;
    qdec = argument0;
    if (qdec > 0) qhex = ""; else qhex="00";
    qh = "0123456789ABCDEF";
    while (qdec > 0) {
        qbyte = qdec & 255;
        qhi = string_char_at(qh,qbyte div 16 + 1);
        qlo = string_char_at(qh,qbyte mod 16 + 1);
        qhex = qhi + qlo + qhex;
        qdec = qdec >> 8;
    }
    return qhex;
}
