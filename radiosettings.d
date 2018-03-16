import std.bitmanip;
import std.conv: to;
import std.stdio;
import std.math : round, quantize;
import std.traits : isFunction, isType, isFunctionPointer, hasUDA, getUDAs, getSymbolsByUDA;

/// Approach 1
class Field
{
    string field_name;

    int min;
    int max;
    string units;
}

class StringField : Field
{
    string value;

    this(string fn, int min, int max, string units) {
        this.field_name = fn;
    }
}

class MultipleChoiceField : Field
{
    string[int] choices;
    int         value;
}

class IntegerField : Field
{
    int  value;
    real function(real data) xform_from_mmap;
    real function(real data) xform_to_mmap;
}

class BooleanField : Field
{
    bool value;
    this (string fn) {
        this.field_name = fn;
    }
}

class RS_A
{
    StringField info_line1 = new StringField("info_line1", 0, 10, "");
    StringField info_line2 = new StringField("info_line2", 0, 10, "");
    
    BooleanField disable_all_leds = new BooleanField("disable_all_leds");
 
    string getX(string field)
    {
        writeln("RS_A::getX");

        // works: writeln(hasUDA!(info_line1, 7));

        //writeln(getSymbolsByUDA!(RS_A, 7));               // prints radiosettings.StringField instead of info_line1

        switch (field) {
            static foreach(fn; __traits(allMembers, RS_A)) {
                static if (hasUDA!(fn, "model")) {
                    pragma(msg, fn);
                    mixin("case \""~fn~"\":");
                    writeln(fn);
                    mixin("writeln(hasUDA!("~fn~", \"model\"));");
                }
            }
            default:    // no assert
        }
        return "<<none yet>>";
    }

    string get(string field)
    {
        writeln("<<RS_A::get>>");
        SWouter:
        switch (field)
        {
            static foreach (f; RS_A.tupleof) {
                case __traits(identifier, f): return f.value.to!string; break SWouter;
        }
            default: assert(0);
        }

        return "(no result)";
    }
}

//////
/// Approach 2

/// Annotations
struct Bounds
{
    int min;
    int max;
}
/// ditto
struct Strlen
{
    int len;
}
/// ditto
struct Units
{
    string units;
}
/// ditto
struct Xform
{
    real function(real data) xform_from_mmap;
    real function(real data) xform_to_mmap;
}

class RS
{
    string get(string field) {
        return "(((none)))";
    }

    @Strlen(10) string info1;
    @Strlen(10) string info2;

    bool disable_all_leds;

    @([ 0: "silent", 1: "open" ])   int monitor_type;

    bool save_preamble;
    bool save_mode_receive;
    bool all_tones;
    bool chfree_indication_tone;
    bool password_and_lock_enable;

    @([ 0: "none", 1: "digital", 2: "analog", 3: "both" ]) int talk_permit_tone;

    // ...
    @Bounds(1, 16776415)    int radio_dmr_id;

    @Units("ms") {
        @Bounds(1, 8640)
        @Xform((x) => x*60, (y) => round(y/60))
                            int tx_preamble;
        @Bounds(0, 7000)
        @Xform((x) => x*100, (y) => round(y/100).quantize(5.0L))
                            int group_call_hangtime;

        @Bounds(0, 7000)
        @Xform((x) => x*100, (y) => round(y/100).quantize(5.0L))
                            int private_call_hangtime;
    }

    @Bounds(0, 255)         int vox_sensitivity;        // TODO: should this be a ubyte instead

    @Units("sec") {
        @Bounds(0, 635)
        @Xform((x) => x*5, (y) => round(y/5))
                            int rx_lowbat_interval;
        @Bounds(0, 1200)
        @Xform((x) => x*5, (y) => round(y/5))
                            int call_alert_tone;
    }

    @Bounds(0, 255)         int loneworker_resp_time;
    @Bounds(0, 255)         int loneworker_reminder_time;

    @Units("ms") {
    @Bounds(25, 500)        int scan_digital_hangtime;
    @Bounds(25, 500)        int scan_analog_hangtime;
    }

    @([ 1: "5 sec", 2: "10 sec", 3: "15 sec", 255: "manual" ])  int keypad_lock_time;
    @([ 0: "MR", 255: "CH" ])   int chan_display_mode;

    @Bounds(0, 99999999)    int poweron_password;
    @Bounds(0, 99999999)    int radio_programming_password;

    string pc_programming_password; // TODO decorate to describe strlen and ascii (not UTF16)

    /// ...

    @([ 0: "Unassigned", 1: "All Tone Alert On/Off", 2: "Emergency On", 3: "Emergency Off",
        4: "High/Low Power", 5: "Monitor", 6: "Nuisance Delete", 7: "One Touch Access 1",
        8: "One Touch Access 2", 9: "One Touch Access 3", 10: "One Touch Access 4", 11: "One Touch Access 5",
        12: "One Touch Access 6", 13: "Repeater/Talkaround", 14: "Scan On/Off", 15: "Tight/Normal Squelch",
        16: "Privacy On/Off", 17: "Vox On/Off", 18: "Zone Increment", 19: "Manual Dial",
        20: "Lone work On/Off", 21: "1750hz Tone", 22: "Disable/Enable LCD backlight (Custom firmware only)"]) {
        ubyte       side_button_top_short;
        ubyte       side_button_top_long;
        ubyte       side_button_bottom_short;
        ubyte       side_button_bottom_long;
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
    /// BEGIN MEMORY MAP ///
    align(1):
    wchar[10]   info1;              // UTF16: 160 bits, 20 octets, 10 UTF16 codepoints
    wchar[10]   info2;              // UTF16: 160 bits, 20 octets, 10 UTF16 codepoints

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
        uint,   "talk_permit_tone", 2));// 520-521

    // byte 0x42
    mixin(bitfields!(
        uint,   "unknown_offset532",4,  // 532-535 -- unknown (padding?)
        bool,   "intro_graphic",     1,  // 531
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

    // byte 0x90 - 0xAF
    ubyte[32]   unknown_offset0x90;         // all set to 0xFF in my codeplug
    // byte 0xB0
    ubyte[16]   unknown_offset0xB0;         // 000020f0  0f 3f ff 3f fb ff ff ff  ff ff ff ff ff ff ff ff  |.?.?............|

    // byte 0xC0
    ubyte       unknown_offset0xC0;         // 00 in my codeplug
    ubyte       unknown_offset0xC1;         // 00 in my codeplug
    // byte 0xC2-C5 are radio side buttons (MD-380)
    // Documented here: https://github.com/travisgoodspeed/md380tools/blob/master/md380_codeplug.py
    ubyte       side_button_top_short;
    ubyte       side_button_top_long;
    ubyte       side_button_bottom_short;
    ubyte       side_button_bottom_long;

    // byte 0xC6 - 0xCF
    ubyte[10]   unknown_offset0xC6;         // zeroed bytes in my codeplug

    // bytes 0xD0 - DF
    // 00002110  01 04 ff ff d1 01 01 00  d1 01 01 00 d1 01 01 00  |................|
    ubyte       unknown_offset0xD0;
    ubyte       unknown_offset0xD1;
    ubyte[2]    unknown_offset0xD2;
    uint        unknown_offset0xD4;         // d1 01 01 00 = 0x000101d1 = 66,001
    uint        unknown_offset0xD8;         // d1 01 01 00 = 0x000101d1 = 66,001
    uint        unknown_offset0xDc;         // d1 01 01 00 = 0x000101d1 = 66,001

    // bytes 0xE0 - EF
    // 00002120  d1 01 01 00 d1 01 01 00  d1 01 01 00 00 00 00 00  |................|
    uint        unknown_offset0xE0;         // d1 01 01 00 = 0x000101d1 = 66,001
    uint        unknown_offset0xE4;         // d1 01 01 00 = 0x000101d1 = 66,001
    uint        unknown_offset0xE8;         // d1 01 01 00 = 0x000101d1 = 66,001
    ubyte[4]    unknown_offset0xEc;         // zeroed in my codeplug

    // bytes 0xF0 - FF
    ubyte[16]   unknown_offset0xF0;         // zeroed in my codeplug

    /// END MEMORY MAP ///
    ////////////////////////////////////////////////////////////////////////////////////////////
    static immutable ubyte zero_value = 0xFF;

    static string[int][string] lut;         // LUT: Lookup table
    static string[string] description;
    static uint[string] min;                /// minimum value (zero if not otherwise specified)
    static uint[string] max;                // maximum value

    alias fnptr = real function(uint data);
    static fnptr[string] transform_out;
    static fnptr[string] transform_in;

    static string[string] field_types;

    static this()
    {
        /// Reflection
        // compile-time AA of types
        static foreach(prop; __traits(allMembers, RadioSettings)) {
            //writeln(typeid( mixin("RadioSettings."~prop))); // radiosettings.d-mixin-110(110): Error: need this for info1 of type (all fields)
            //mixin("field_types[\"" ~ prop ~ "\"] = typeid(this." ~ prop ~ ");");
            //mixin("field_types[\"" ~ prop ~ "\"] = info1;");
        }
        writeln("field_types:");
        writeln(field_types);

        lut["monitor_type"]     = [ 0: "silent", 1: "open" ];
        lut["talk_permit_tone"] = [ 0: "none", 1: "digital", 2: "analog", 3: "both" ];
        //lut["intro_screen"]     = [ 0: "charstrings", 1: "picture" ];
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

        // Not sure whether I prefer mixin string lambda functions or
        // the traditional way as in tranform_in
        enum XFORM_OUT = [  ["tx_preamble", "(x) => x*60;"],
                            ["group_call_hangtime", "(x) => x*100;"],
                            ["private_call_hangtime", "(x) => x*100;"],
                            ["rx_lowbat_interval", "(x) => x*5;"],
                            ["call_alert_tone", "(x) => x*5;"],
                            ["scan_digital_hangtime", "(x) => x*5;"],
                            ["scan_analog_hangtime", "(x) => x*5;"] ];
        static foreach(xform; XFORM_OUT) {
            mixin("transform_out[\"" ~ xform[0] ~ "\"] = " ~ xform[1]);
        }

        transform_in["tx_preamble"] = (y) => round(y/60);
        transform_in["group_call_hangtime"] = (y) => round(y/100).quantize(5.0L);
        transform_in["private_call_hangtime"] = (y) => round(y/100).quantize(5.0L);
        transform_in["rx_lowbat_interval"] = (y) => round(y/5);
        transform_in["call_alert_tone"] = (y) => round(y/5);
        transform_in["scan_digital_hangtime"] = (y) => round(y/5);
        transform_in["scan_analog_hangtime"] = (y) => round(y/5);

        // debugging only
        writeln("DEBUG: static foreach prop; __traits(allMembers, RadioSettings");
        static foreach(prop; __traits(allMembers, RadioSettings)) {
                writeln("Static foreach: ", prop);
                //writeln("Get member: ", __traits(getMember, prop, this));
        }

    }

    T getTemplate(T)(string field)
    {
        /// BUG: Need *_password, which are ubyte[4]
        enum FIELDS = [ "disable_all_leds", "monitor_type", "talk_permit_tone",
                        "radio_dmr_id",
                        "tx_preamble", "group_call_hangtime", "private_call_hangtime", "vox_sensitivity",
                        "rx_lowbat_interval", "call_alert_tone",
                        "loneworker_resp_time", "loneworker_reminder_time", "scan_digital_hangtime", "scan_analog_hangtime", "keypad_lock_time",
                        "chan_display_mode"];
        uint val;   // should this be T val; ?

        GetterSwitch:
        switch (field)
        {
            static foreach(prop; FIELDS ) {
                mixin("case \"" ~ prop ~ "\": val = this." ~ prop ~ "; break GetterSwitch;");
            }
            default:
                val = 0;
                assert(0);  // This is to prevent subtle bugs, but I need a better error handler
        }
        
        //auto val = __traits(getMember, this, field);
        static if(is(T == real)) {
            if (field in transform_out)
                return transform_out[field](val);
            else return val;
        }
        else static if(is(T == string)) {
        if (field in lut)
            return lut[field][val]; // could be subtle bug with val=0 if field value not retrieved in the switch(field) above
        }
        
        // Should not reach here
        // (means template instantiated with wrong type)
        assert(0);
    }

    string get(string field)
    {
        Souter:
        switch (field)
        {
            static foreach(prop; __traits(allMembers, RadioSettings))
            {
                static if (! isFunction!(mixin("RadioSettings."~prop)) && !isFunctionPointer!(mixin("RadioSettings."~prop)) && !__traits(isTemplate, mixin("RadioSettings."~prop)) )
                {
                    //pragma(msg, prop);
                    case prop:
                        mixin("return this."~prop~".to!string; break Souter;");
                }
            }
            default:
                writeln(field);
                assert(0);
        } // end swich
        assert(0);
    }
}
static this()
{
    writeln("<Static module constructor radiosettings.d>");
    RadioSettings rs;
    /// Reflection
    // compile-time AA of types
    static foreach(prop; __traits(allMembers, RadioSettings)) {
        static if (!isFunction!(mixin("RadioSettings."~prop)) && !isFunctionPointer!(mixin("RadioSettings."~prop)) && !__traits(isTemplate, mixin("RadioSettings."~prop)) )
            mixin("writeln(prop, \" => \", typeid(rs."~prop~"));");
    }
    writeln("<end static module constructor>");
}