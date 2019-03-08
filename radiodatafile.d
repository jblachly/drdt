import std.file;
import std.stdio;

import radiodata;
import radiosettings;

///
class MD380CodeplugFile
{
    static immutable int rdt_headerlen = 549;           /// unknown content
    static immutable ubyte[rdt_headerlen] rdt_header;   /// ditto
    static immutable ubyte[16] rdt_footer = [
        0x00, 0x02, 0x11, 0xdf, 0x83, 0x04, 0x1a, 0x01, 
        0x55, 0x46, 0x44, 0x10, 0x12, 0x71, 0x65, 0x8e];/// ditto

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

    RadioSettings           settings;       /// Radio settings
    Table!TextMessage       textmessages;   /// Predefined text messages
    Table!ContactInformation contacts;      /// Contact list
    Table!RxGroup           rxgroups;       /// RX groups (each a list of channels)
    Table!ZoneInfo          zones;          /// Zones (each a list of channels)
    Table!ScanList          scanlists;      /// Scanning lists (each a list of channels)
    Table!ChannelInformation channels;      /// Channel data

    /// default constructor sets up empty Tables 
    this()
    {
        // TODO, these sizes could be parameterized to support different formats
        // settings already allocated as struct;
        this.textmessages = new Table!(TextMessage)(50);
        this.contacts = new Table!(ContactInformation)(1000);
        this.rxgroups = new Table!(RxGroup)(250);
        this.zones =    new Table!(ZoneInfo)(250);
        this.scanlists =new Table!(ScanList)(250);
        this.channels = new Table!(ChannelInformation)(1000);
    }

    /** load_from_file
     *
     *  Populates the MD380CodePlugFile data model's constituent models
     *  from an RDT or BIN (raw memory dump) codeplug file
     */
    int load_from_file(File f, bool is_rdtfile)
    {
        // closure over f and is_rdtfile
        // without 'ref' RadioSettings being a Value type is copied , stupid bug
        void seek_and_read_into(T)(int offset, ref T data_table) {
            //auto immutable offset = data_table.offset;
            f.seek(offset + (is_rdtfile ? rdt_headerlen : 0));
            static if(is(T == RadioSettings))
                f.rawRead(cast(RadioSettings[1])data_table);
            else {
                f.rawRead(data_table.rows);
                //data_table.range = data_table.rows; // TODO when updating Range to Forward or Bidirectional or RandomAccessRange, fix this
            }
        }

        // TODO Grab the header (footer?) in case it is important ...

        // Should settings be encapsulated in Table or not?
        // I can cast to array of length 1 to deserialize (see above static if)
        seek_and_read_into(0x2040, this.settings);

        seek_and_read_into(0x2180, this.textmessages);
        seek_and_read_into(0x5f80, this.contacts);
        seek_and_read_into(0xec20, this.rxgroups);
        seek_and_read_into(0x149e0, this.zones);
        seek_and_read_into(0x18860, this.scanlists);
        seek_and_read_into(0x1ee00, this.channels);

        return 0;   // success?
    }

    /** update_file
     *
     *  updates an existing file in place in its totality -- 
     *  all sections of the file are automatically updated
     *  from the underlying model
     */ 
    int update_file(File f, bool is_rdtfile)
    {
        // TODO: catch exception, if file descriptor
        // not opened for update or write, will crash with exception
        // todo: won't work with settings yet without static if
        void seek_and_update(T)(ref T data_table) {
            auto immutable offset = data_table.first_record_offset;
            f.seek(offset + (is_rdtfile ? rdt_headerlen : 0));
            static if(is(T == RadioSettings))
                f.rawWrite(cast(RadioSettings[1])data_table);
            else 
                f.rawWrite(data_table.rows);
        }

        seek_and_update(this.settings);

        seek_and_update(this.textmessages);
        seek_and_update(this.contacts);
        seek_and_update(this.rxgroups);
        seek_and_update(this.zones);
        seek_and_update(this.scanlists);
        seek_and_update(this.channels);

        return 0;
    }

    /** dump_to_new_file
     *
     *  Serializes the MD380CodePlugFile and its constituent data models
     *  to a brand new RDT or BIN (raw memory dump) file,  
     *  including filling in unknown gaps between the models,
     *  and in the case of RDT, synthesizing a header and footer with
     *  empirical but unknown data pulled from an existing RDT file
     */
    int dump_to_new_file(string filename, bool is_rdtfile)
    {
        assert(0);
        return -1;
    }
}
