module encoding;

import std.math : log10;
import std.stdio : writeln;

/** Decode a (little Endian) BCD encoded series of bytes to integer (uint32) */
uint bcd_decode(ubyte *data, int n_octets)
{
    // Little Endian decoder
    assert(n_octets <= 4);  // Would overflow a 32-bit uint somewhere in middle of 5 octets

    uint basepow = 0;
    uint cumsum = 0;

    for(int i=0;i<n_octets;i++) {
        // Low nybble to high nybble
        cumsum += (data[i] & 0b00001111) * (10 ^^ basepow);
        basepow += 1;
        cumsum += ((data[i] &0b11110000) >> 4) * (10 ^^ basepow);
        basepow += 1;
    }

    return cumsum;
}
unittest
{
    ubyte[2] data2 = [0x00, 0x00];
    assert( bcd_decode(cast(ubyte *)data2, 2) == 0 );

    data2 = [0x01, 0x00];
    assert( bcd_decode(cast(ubyte *)data2, 2) == 1 );

    data2 = [0x10, 0x00];
    assert( bcd_decode(cast(ubyte *)data2, 2) == 10 );

    data2 = [0x00, 0x01];
    assert( bcd_decode(cast(ubyte *)data2, 2) == 100 );

    data2 = [0x00, 0x10];    
    assert( bcd_decode(cast(ubyte *)data2, 2) == 1000 );

    data2 = [0x34, 0x12];    
    assert( bcd_decode(cast(ubyte *)data2, 2) == 1234 );
    
    ubyte[4] data4 = [0x40, 0x30, 0x20, 0x10];
    assert( bcd_decode(cast(ubyte *)data4, 4) == 10203040);
}


/** BCD encode (litte Endian) an integer (uint32) */
ubyte[] bcd_encode(uint dec_value, uint n_octets)
{
    // Check that we have sufficient encoding space
    assert( log10(dec_value) < (n_octets * 2) );

    ubyte[] encoded;
    encoded.length = n_octets;

    for(int i=0; i<n_octets; i++) {
        ubyte low_nybble = dec_value % 10;
        dec_value /= 10;
        ubyte high_nybble = dec_value % 10;
        dec_value /= 10;

        ubyte octet = ((high_nybble & 0x0f) << 4) | (low_nybble&0x0f);

        encoded[i] = octet;
    }

    return encoded;
}
unittest
{
    assert( bcd_encode(1,   2) == [0x01, 0x00] );
    assert( bcd_encode(10,  2) == [0x10, 0x00] );
    assert( bcd_encode(100, 2) == [0x00, 0x01] );
    assert( bcd_encode(1000,2) == [0x00, 0x10] );

}
