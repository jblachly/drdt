import std.bitmanip;
import std.file;
import std.stdio;
import std.conv;
import std.string : lastIndexOf;
import std.getopt;

import std.math : round, quantize;

import radiosettings;

//import witchcraft;

// http://forum.dlang.org/thread/eiquqszzycomrcazcfsb@forum.dlang.org
// http://www.iz2uuf.net/wp/index.php/2016/06/04/tytera-dm380-codeplug-binary-format/

// table,tabledef_fn,num_records,first_record_offset,record_length,zero_value,deletion_marker_offset,deletion_marker_value

immutable int rdt_headerlen = 549;
immutable ubyte[rdt_headerlen] rdt_header;
immutable ubyte[16] rdt_footer = [0x00, 0x02, 0x11, 0xdf, 0x83, 0x04, 0x1a, 0x01, 0x55, 0x46, 0x44, 0x10, 0x12, 0x71, 0x65, 0x8e];

class Table(T)
{
    T[] rows;

    this(ulong max_records)
    {
        writeln("Table constructor generic");

        this.rows.length = max_records; // Forces reallocation (and copy if applic)
    }
    /*
    this(T: Table!TextMessage)(int max_records)
    {
        writeln("Constructor specialized");
        this.rows.length = max_records;  // Forces reallocation (and copy if applic)
        this.first_record_offset = 0x2180;      // raw, not RDT
    }*/
    // needed for ForwardRange
    auto dup() const
    {
        auto copy = new Table!T(rows.length);
        copy.rows = this.rows.dup;
        //writeln("DEBUG");
        //writeln("copy.rows: ", copy.rows);
        return copy;
    }

    @property uint record_length() const {
        return T.sizeof;
    }
    @property ulong max_records() const {
        return rows.length;
    }

    // Manipulation functions


    /// InputRange
    @property bool empty() const {
        // If the first record is zeroed, we will consider range empty
        return (this.rows[0].empty);
    }
    @property ref T front() {
        // ref is used since we are dealing wiht Structs (value type; do not want to make a copy)
        return (this.rows[0]);
    }
    void popFront() {
        this.rows = this.rows[1 .. $];
    }
    // ForwardRange
    @property typeof(this) save() const {
        return this.dup;
    }

    // RandomAccessRange
    T opIndex(size_t index) const {
        return this.rows[index];
    }
}



// textmessages,fields_textmsg.csv,50,9125,288,0,0,0
struct TextMessage
{
    static immutable uint first_record_offset = 0x2180;
    static immutable wchar deletion_marker = 0;
    static immutable int deletion_marker_offset = 0;
    bool empty() const @property {
        return (message[this.deletion_marker_offset] == this.deletion_marker);
    }

    wchar[144] message; // UTF16: 288 octets; 2304 bytes

    string toString() {
        return this.message.to!string;
    }
}

// contacts,fields_contact.csv,1000,24997,36,255,4,5
struct ContactInformation
{
    static immutable uint first_record_offset = 0x5f80;
    static immutable wchar deletion_marker = 0;
    static immutable int deletion_marker_offset = 0;
    bool empty() const @property {
        return (contact_name[this.deletion_marker_offset] == this.deletion_marker);
    }

    align(1):
    // NB: Here, the D bitmanip bitfield seems to handle 24 bit integer OK,
    // whereas in the radio settings section is does not.
    // LSB first
    mixin(bitfields!(
        uint, "contact_dmr_id",     24, // 0 - 23   (3 octets)
        uint, "call_type",          2,  // 30-31
        uint, "unknown_offset27_28",3,  // 27-29 -- unknown (padding?)
        bool, "call_receive_tone",  1,  // 26
        uint, "unknown_offset24",   2,  // 24-25 -- unknown (padding?)
    ));

    wchar[16]   contact_name;           // 256 bits -> 32 octets -> 16 UTF16 codepoints
}

// rxgroups,fields_rxgroup.csv,250,60997,96,0,0,0
struct RxGroup
{
    static immutable uint first_record_offset = 0xec20;
    static immutable wchar deletion_marker = 0;
    static immutable int deletion_marker_offset = 0;
    bool empty() const @property {
        return (rxgroup_name[this.deletion_marker_offset] == this.deletion_marker);
    }

    wchar[16]   rxgroup_name;           // 256 bits -> 32 octets -> 16 UTF16 codepoints
    ushort[32]  contact_ids;            // 512 bits = 32 * 16-bit contact id (lookup into contacts table)
}

// zones,fields_zone.csv,250,84997,64,0,0,0
struct ZoneInfo
{
    static immutable uint first_record_offset = 0x149e0;
    static immutable wchar deletion_marker = 0;
    static immutable int deletion_marker_offset = 0;
    bool empty() const @property {
        return (name[this.deletion_marker_offset] == this.deletion_marker);
    }

    wchar[16]   name;                 // 256 bits / 32 octets
    ushort[16]  channel_ids;
}

// scanlists,fields_scanlist.csv,250,100997,104,0,0,0
struct ScanList
{
    static immutable uint first_record_offset = 0x18860;
    static immutable wchar deletion_marker = 0;
    static immutable int deletion_marker_offset = 0;
    bool empty() const @property {
        return (name[this.deletion_marker_offset] == this.deletion_marker);
    }

    wchar[16]   name;               // 32 octets
    ushort      priority_channel1;  // offset: 256
    ushort      priority_channel2;  // offset: 272
    ushort      tx_channel;         // offset: 288

    ubyte       unknown_offset304;  // offset: 304 -- padding?

    ubyte       sign_hold_time;     // offset: 312
    ubyte       priority_sample_time;//offset: 320

    // Yes, there are only 31 slots (not 32) in a scan list
    ushort[31]  channel_ids;        // offset: 336
}

// TODO: fix bitfields
// channels,fields_channel.csv,1000,127013,64,255,16,255
struct ChannelInformation
{
    static immutable uint first_record_offset = 0x1EE00;
    static immutable ubyte deletion_marker = 0xFF;
    static immutable int deletion_marker_offset = 128;  // rx frequency
    bool empty() const @property {
        return ((cast(ubyte*)&this)[deletion_marker_offset] == this.deletion_marker);
    }

    align(1):
    // Bitfields are allocated from LSB, so these are broken into groups of 8 bits for clarity
    // byte 0x00
    mixin(bitfields!(               // bit offset numbering from MSB (i.e. from beginning of memory)
        uint, "channel_mode",   2,  // 6-7
        bool, "unknown_offset5",1,  // 5 -- unk
        bool, "bandwidth",      1,  // 4
        bool, "autoscan",       1,  // 3
        bool, "squelch",        1,  // 2
        bool, "unknown_offset1",1,  // 1 -- unk
        bool, "lone_worker",    1));// 0

    // byte 0x01
    mixin(bitfields!(
        bool, "allow_talkaround",1, // 15
        bool, "rx_only",        1,  // 14
        uint, "time_slot",      2,  // 12-13
        uint, "color_code",     4));// 8-11

    // byte 0x02
    mixin(bitfields!(
        uint, "privacy_no",     4,  // 20-23
        uint, "privacy",        2,  // 18-19
        bool, "private_call_conf",1,// 17
        bool, "data_call_conf", 1));// 16

    // byte 0x03
    mixin(bitfields!(
        uint, "rx_ref_frequency",       2,  // 30-31
        bool, "unknown_offset29",       1,  // 29 -- unknown
        bool, "emergency_alarm_ack",    1,  // 28
        uint, "unknown_off_26_27",      2,  // 26-27 -- unknown
        bool, "compressed_udp_header",  1,  // 25
        bool, "display_ptt_id", 1));        // 24

    // byte 0x04
    mixin(bitfields!(
        uint, "tx_ref_frequency",   2,  // 38-39
        bool, "reverse_burst",      1,  // 37
        bool, "qt_reverse",         1,  // 36
        bool, "vox",                1,  // 35
        bool, "power",              1,  // 34
        uint, "admit_criteria",     2));// 32

    // byte 0x05
    ubyte unknown_offset40;             // 40-47

    // bytes 0x06-0x07
    ushort contact_name_id;             // 48-63 -- refers to entry in contacts table
    
    // byte 0x08
    mixin(bitfields!(
        uint, "timeout_time",       6,  // 66-71
        uint, "unknown_offset64_65",2));// 64-65 -- unknown

    // byte 0x09
    ubyte tot_rekey_delay;              // 72-79

    // byte 0x0a
    mixin(bitfields!(
        uint, "emergency_system",   6,  // 82-87
        uint, "unknown_offset80_81",2));// 80-81 -- unknown

    // byte 0x0b
    ubyte scan_list;                    // 88-95 -- Foreign key 

    // byte 0x0c
    ubyte group_list;                   // 96-103 -- Foreign key

    // byte 0x0d
    ubyte unknown_offset104;            // 104-111

    // byte 0x0e
    ubyte decode18;                     // 112-119

    // byte 0x0f
    ubyte unknown_offset120;            // 120-127

    // bytes 0x10-0x13, 0x14-0x17 (32 bits each)
    uint rx_frequency;                  // 128-159  -- BCD encoded
    uint tx_frequency;                  // 160-191  -- BCD encoded

    // bytes 0x18-19, 0x1a-1b (16 bits each)
    ushort ctcss_dcs_decode;            // 192-207  -- BCDT encoded
    ushort ctcss_dcs_encode;            // 208-223  -- BCDT encoded

    // byte 0x1c
    mixin(bitfields!(
        uint, "rx_signaling_system",   3,   // 229-231
        uint, "unknown_offset224_228", 5)); // 224-228  -- padding?

    // byte 0x1d
    mixin(bitfields!(
        uint, "tx_signaling_system",   3,   // 237-239
        uint, "unknown_offset232_236", 5)); // 232-236  -- padding?

    // bytes 0x1e-1f
    ushort unknown_offset240_255;           // 240-255
    
    // bytes 0x20-3f (wchar = 2 octets)
    wchar[16] channel_name;

    string toString() const {
        return channel_name.to!string;
    }
}

static this()
{
    // Sanity checks
    static assert(RadioSettings.sizeof == 256);
    static assert(TextMessage.sizeof == 288);
    static assert(ContactInformation.sizeof == 36);
    static assert(RxGroup.sizeof == 96);
    static assert(ZoneInfo.sizeof == 64);
    static assert(ScanList.sizeof == 104);
    static assert(ChannelInformation.sizeof == 64);

    static assert(__traits(isPOD, RadioSettings));
    static assert(__traits(isPOD, TextMessage));
    static assert(__traits(isPOD, ContactInformation));
    static assert(__traits(isPOD, RxGroup));
    static assert(__traits(isPOD, ZoneInfo));
    static assert(__traits(isPOD, ScanList));
    static assert(__traits(isPOD, ChannelInformation));
}