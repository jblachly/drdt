import std.file;
import std.stdio;

import radiodata;

class MD380CodeplugFile
{
    static immutable int rdt_headerlen = 549;
    static immutable ubyte[rdt_headerlen] rdt_header;
    static immutable ubyte[16] rdt_footer = [0x00, 0x02, 0x11, 0xdf, 0x83, 0x04, 0x1a, 0x01, 0x55, 0x46, 0x44, 0x10, 0x12, 0x71, 0x65, 0x8e];

    // https://dlang.org/spec/hash-map.html#static_initialization
    // is wrong; apparently static initialization of AAs was never implemented even though speced
    /*static immutable int[string] first_record_offset = [
        "Settings":             0x2040,
        "TextMessage":          0x2180,
        "ContactInformation":   0x5f80,
        "RxGroup":              0xec20,
        "ZoneInfo":             0x149e0,
        "ScanList":             0x18860,
        "ChannelInformation":   0x1EE00,
    ]; */

    RadioSettings           settings;
    Table!TextMessage       textmessages;
    Table!ContactInformation contacts;
    Table!RxGroup           rxgroups;
    Table!ZoneInfo          zones;
    Table!ScanList          scanlists;
    Table!ChannelInformation channels;

    this()
    {
        // settings already allocated as struct;
        this.textmessages = new Table!(TextMessage)(50);
        this.contacts = new Table!(ContactInformation)(1000);
        this.rxgroups = new Table!(RxGroup)(250);
        this.zones =    new Table!(ZoneInfo)(250);
        this.scanlists =new Table!(ScanList)(250);
        this.channels = new Table!(ChannelInformation)(1000);
    }

    int load_from_file(File f, bool is_rdtfile)
    {
        // closure over f and is_rdtfile
        // without 'ref' RadioSettings being a Value type is copied , stupid bug
        void seek_and_read_into(T)(int offset, ref T data_table) {
            f.seek(offset + (is_rdtfile ? rdt_headerlen : 0));
            static if(is(T == RadioSettings))
                f.rawRead(cast(RadioSettings[1])data_table);
            else {
                f.rawRead(data_table.rows);
                //data_table.range = data_table.rows; // TODO when updating Range to Forward or Bidirectional or RandomAccessRange, fix this
            }
        }

        // Also need to do settings -- not sure best way (encpsulate in Table or not?)
        // it apears I can cast to array of length 1 to deserialize
        seek_and_read_into(0x2040, this.settings);

        seek_and_read_into(0x2180, this.textmessages);
        seek_and_read_into(0x5f80, this.contacts);
        seek_and_read_into(0xec20, this.rxgroups);
        seek_and_read_into(0x149e0, this.zones);
        seek_and_read_into(0x18860, this.scanlists);
        seek_and_read_into(0x1ee00, this.channels);

        return 0;   // success?
    }
}