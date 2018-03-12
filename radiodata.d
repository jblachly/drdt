import std.bitmanip;
import std.file;
import std.stdio;
import std.conv;
import std.string : lastIndexOf;
import std.getopt;


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
        writeln("Constructor generic");

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

/**
 * RadioSettings struct is a memory map of radio settings from radio codeplug
 *
// settings,fields_settings.csv,1,8805,144,255,0,255
// raw codeplug (.bin): starts at 8256 (0x2040)
*/
struct RadioSettings
{
    static immutable ubyte zero_value = 0xFF;

    align(1):
    wchar[10]   info1;  // UTF16: 160 bits, 20 octets, 10 UTF16 codepoints
    wchar[10]   info2;  // UTF16: 160 bits, 20 octets, 10 UTF16 codepoints

    ubyte[24]   unknown_offset320;  // 320 -- padding?

    // Bitfields are allocated from LSB, so these are broken into groups of 8 bits for clarity
    // byte 0x40
    mixin(bitfields!(
        uint,   "unknown_offset518",2,  // 518-519 -- unknown
        bool,   "disable_all_leds", 1,  // 517
        bool,   "unknown_offset516",1,  // 516 -- unknown
        uint,   "monitor_type",     1,  // 515
        uint,   "unknown_offset512",3));// 512-514

    // byte 0x41
    mixin(bitfields!(
        bool,   "save_preamble",    1,  // 527  (LSB)
        bool,   "save_mode_receive",1,  // 526
        bool,   "all_tones",        1,  // 525
        bool,   "unknown_offset524",1,  // 524
        bool,   "chfree_indication_tone",   1,  // 523
        bool,   "password_and_lock_enable", 1,  // 522
        bool,   "unknown_offset521", 1,
        bool,   "talk_permit_tone", 1));// 520

    // byte 0x42
    mixin(bitfields!(
        uint,   "unknown_offset532",4,  // 532-535 -- unknown (padding?)
        bool,   "intro_screen",     1,  // 531
        bool,   "keypad_tones",     1,  // 530
        uint,   "unknown_offset528",2));// 528-529

    // byte 0x43
    ubyte    unknown_offset536;      // 536-543 -- unknown

    /*
    // byte 0x44-46 + 0x47 (alltogether for bitfield purposes; must sum to 32 bits; LSB first)
    mixin(bitfields!(
        ubyte,   "unknown_offset568",8,  // 568-575 -- byte 0x47 -- unknown (padding?)

        uint,   "radio_dmr_id",     24   // 544-567
    ));
    */
    // NB: Evidently D bitmanip bitfields cannot handle packed 24 bit int followed by byte; parses as 16 bits each
    // byte 0x44 - 0x47 (where 0x47 should always be zeroed out as the allowable range is 24 bits [or less?])
    uint    radio_dmr_id;                // 544 - 575

    // bytes 0x48 - 0x4b
    ubyte   tx_preamble;
    ubyte   group_call_hangtime;
    ubyte   private_call_hangtime;
    ubyte   vox_sensitivity;

    // bytes 0x4c, 0x4d
    ushort  unknown_offset608;              // 608-623

    // bytes 0x4e, 0x4f
    ubyte   rx_lowbat_interval;
    ubyte   call_alert_tone;

    // bytes 0x50 - 0x57 (bits 640 - 703)
    ubyte   loneworker_resp_time;
    ubyte   loneworker_reminder_time;
    ubyte   unknown_offset656;
    ubyte   scan_digital_hangtime;
    ubyte   scan_analog_hangtime;
    ubyte   unknown_offset680;
    ubyte   keypad_lock_time;
    ubyte   chan_display_mode;

    ubyte[4]    poweron_password;           // 704
    ubyte[4]    radio_programming_password; // 736
    ubyte[8]    pc_programming_password;    // 768-831
    
    ubyte[8]    unknown_offset832;          // 832

    wchar[16]   radio_name;                 // 896. 256 bits -> 32 octets -> 16 UTF16 codepoints
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
    mixin(bitfields!(
        bool, "lone_worker",    1,  // 0
        bool, "unknown_offset1",1,  // 1 -- unk
        bool, "squelch",        1,  // 2
        bool, "autoscan",       1,  // 3
        bool, "bandwidth",      1,  // 4
        bool, "unknown_offset5",1,  // 5 -- unk
        uint, "channel_mode",   2,  // 6-7

        uint, "color_code",     4,  // 8-11
        uint, "time_slot",      2,  // 12-13
        bool, "rx_only",        1,  // 14
        bool, "allow_talkaround",1, // 15

        bool, "data_call_conf", 1,  // 16
        bool, "private_call_conf",1,// 17
        uint, "privacy",        2,  // 18-19
        uint, "privacy_no",     4,  // 20-23

        bool, "display_ptt_id", 1,          // 24
        bool, "compressed_udp_header",  1,  // 25
        uint, "unknown_off_26_27",      2,  // 26-27 -- unknown
        bool, "emergency_alarm_ack",    1,  // 28
        bool, "unknown_offset29",       1,  // 29 -- unknown
        uint, "rx_ref_frequency",       2,  // 30-31

        uint, "admit_criteria",     2,  // 32
        bool, "power",              1,  // 34
        bool, "vox",                1,  // 35
        bool, "qt_reverse",         1,  // 36
        bool, "reverse_burst",      1,  // 37
        uint, "tx_ref_frequency",   2,  // 38-39

        char, "unknown_offset40",   8,  // 40-47

        uint, "contact_name_id",       16, // 48-63     -- refers to entry in contacts table
    ));

    mixin(bitfields!(
        uint, "unknown_offset64_65",2,  // 64-65 -- unknown
        uint, "timeout_time",       6,  // 66-71

        uint, "tot_rekey_delay",    8,  // 72-79

        uint, "unknown_offset80_81",2,  // 80-81 -- unknown
        uint, "emergency_system",   6,  // 82-87

        uint, "scan_list",          8,  // 88-95

        uint, "group_list",         8,  // 96-103

        uint, "unknown_offset104",  8,  // 104-111

        uint, "decode18",           8,  // 112-119

        uint, "unknown_offset120",  8));// 120-127

    mixin(bitfields!(
        uint, "rx_frequency",       32, // 128-159
        uint, "tx_frequency",       32)); // 160-191
    
    mixin(bitfields!(
        uint, "ctcss_dcs_decode",   16, // 192-207
        uint, "ctcss_dcs_encode",   16, // 208-223

        uint, "unknown_offset224_228",  5,  // 224-228  -- padding?
        uint, "rx_signaling_system", 3,     // 229-231

        uint, "unknown_offset232_236",  5,  // 232-236  -- padding?
        uint, "tx_signaling_system", 3,     // 237-239

        uint, "unknown_offset240_255", 16));// 240-255
    
    
    wchar[16] channel_name;

    string toString() {
        return channel_name.to!string;
    }
}


static this()
{
    // Sanity checks
    static assert(RadioSettings.sizeof == 144);
    static assert(TextMessage.sizeof == 288);
    static assert(ContactInformation.sizeof == 36);
    static assert(RxGroup.sizeof == 96);
    static assert(ZoneInfo.sizeof == 64);
    static assert(ScanList.sizeof == 104);
    static assert(ChannelInformation.sizeof == 64);
}