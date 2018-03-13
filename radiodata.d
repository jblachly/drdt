import std.bitmanip;
import std.file;
import std.stdio;
import std.conv;
import std.string : lastIndexOf;
import std.getopt;

import std.math : round, quantize;

import witchcraft;

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

/**
 * RadioSettings struct is a memory map of radio settings from radio codeplug
 *
 * settings,fields_settings.csv,1,8805,144,255,0,255
 * raw codeplug (.bin): starts at 8256 (0x2040)
*/
struct RadioSettings
{
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

    ////////////////////////////////////////////////////////////////////////////////////////////
    static immutable ubyte zero_value = 0xFF;

    static string[int][string] lut;         // LUT: Lookup table
    static string[string] description;
    static uint[string] min;                /// minimum value (zero if not otherwise specified)
    static uint[string] max;                // maximum value

    alias fnptr = real function(uint data);
    static fnptr[string] transform_out;
    static fnptr[string] transform_in;

    static this()
    {
        lut["monitor_type"]     = [ 0: "silent", 1: "open" ];
        lut["talk_permit_tone"] = [ 0: "none", 1: "digital", 2: "analog", 3: "both" ];
        lut["intro_screen"]     = [ 0: "charstrings", 1: "picture" ];
        lut["keypad_lock_time"] = [ 1: "5 sec", 2: "10 sec", 3: "15 sec", 255: "manual" ];
        lut["chan_display_mode"]= [ 0: "MR", 255: "CH" ];

        description["tx_preamble"] = "Time in msec";
        description["group_call_hangtime"] = "Time in msec";
        description["private_call_hangtime"] = "Time in msec";
        description["rx_lowbat_interval"] = "Time in sec.";
        description["call_alert_tone"] = "Time in sec. (if 0, continue)";
        description["scan_digital_hangtime"] = "Time in msec";
        description["scan_analog_hangtime"] = "Time in msec";

        max["radio_dmr_id"] = 16776415;

        max["tx_preamble"] = 8640;

        max["group_call_hangtime"] = 7000;
        max["private_call_hangtime"] = 7000;

        max["rx_lowbat_interval"] = 635;

        max["call_alert_tone"] = 1200;

        // "default N=10" per http://www.iz2uuf.net/wp/index.php/2016/06/04/tytera-dm380-codeplug-binary-format/
        min["scan_digital_hangtime"] = 25;
        max["scan_digital_hangtime"] = 500;
        min["scan_analog_hangtime"] = 25;
        max["scan_analog_hangtime"] = 500;

        transform_out["tx_preamble"] = (x) => x*60;
        transform_out["group_call_hangtime"] = (x) => x*100;
        transform_out["private_call_hangtime"] = (x) => x*100;
        transform_out["rx_lowbat_interval"] = (x) => x*5;
        transform_out["call_alert_tone"] = (x) => x*5;
        transform_out["scan_digital_hangtime"] = (x) => x*5;
        transform_out["scan_analog_hangtime"] = (x) => x*5;
        

        transform_in["tx_preamble"] = (y) => round(y/60);
        transform_in["group_call_hangtime"] = (y) => round(y/100).quantize(5.0L);
        transform_in["private_call_hangtime"] = (y) => round(y/100).quantize(5.0L);
        transform_in["rx_lowbat_interval"] = (y) => round(y/5);
        transform_in["call_alert_tone"] = (y) => round(y/5);
        transform_in["scan_digital_hangtime"] = (y) => round(y/5);
        transform_in["scan_analog_hangtime"] = (y) => round(y/5);
    }

    auto get(string field)
    {
        uint val;
        // TODO: replace with mixin template
        switch (field)
        {
            case "tx_preamble":
                val = this.tx_preamble;
                break;
            case "group_call_hangtime":
                val = this.group_call_hangtime;
                break;
            case "private_call_hangtime":
                val = this.private_call_hangtime;
                break;
            case "rx_lowbat_interval":
                val = this.rx_lowbat_interval;
                break;
            case "call_alert_tone":
                val = this.call_alert_tone;
                break;
            case "scan_digital_hangtime":
                val = this.scan_digital_hangtime;
                break;
            case "scan_analog_hangtime":
                val = this.scan_analog_hangtime;
                break;
            default:
                val = 0;
        }
        //auto val = __traits(getMember, this, field);
        if (field in transform_out)
            return transform_out[field](val);
        else
            return val;
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
    static assert(RadioSettings.sizeof == 144);
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