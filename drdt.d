import std.bitmanip;
import std.file;
import std.stdio;
import std.conv;
import std.string : lastIndexOf;
import std.getopt;

import radiodata;
import radiosettings;
import radiodatafile;

// http://forum.dlang.org/thread/eiquqszzycomrcazcfsb@forum.dlang.org
// http://www.iz2uuf.net/wp/index.php/2016/06/04/tytera-dm380-codeplug-binary-format/



int main(string[] args) {

    string infile;
    bool is_rdtfile;

    string outfile;

    bool show_settings;
    bool dump_csv;

    auto res = getopt(args,
                "infile|i", "Input codeplug file (.rdt or .bin)", &infile,
                "outfile|o","Output file (.rdt or .bin)", &outfile,
                "settings|s", "Show radio settings", &show_settings,
                "dumpcsv|d", "Dump data tables at CSV", &dump_csv, );
    
    if (res.helpWanted) {
        defaultGetoptPrinter("\ndRDT: Manipulate RDT codeplug files\n", res.options);
        writeln();
        return 1;
    }

    if(!infile.length) {
        writeln("Please specify an input file with -i/--infile");
        return -1;
    }
    
    // TODO check bin/rdt file length is correct
    if (infile[lastIndexOf(infile, '.') .. $] == ".rdt") {
        writeln("RDT file");
        is_rdtfile = true;
    }
    else {
        writeln("Assuming BIN file");
    }
    auto f = File(infile, "r+");
    scope(exit) f.close();

    MD380CodeplugFile datafile = new MD380CodeplugFile;
    datafile.load_from_file(f, is_rdtfile);

    writeln("Radio name: ", datafile.settings.radio_name.to!string);
    writeln("info_line1: ", datafile.settings.info_line1.to!string);
    writeln("info_line2: ", datafile.settings.info_line2.to!string);

    writeln("Now trying getters / setters:");
    writeln("scan_digital_hangtime: ", datafile.settings.description["scan_digital_hangtime"]);
    //writeln("scan_digital_hangtime: ", datafile.settings.get!real("scan_digital_hangtime"));
    //writeln("scan_digital_hangtime: ", datafile.settings.get("scan_digital_hangtime"));

    /*
    writeln("Talk permit tone: ", datafile.settings.get!string("talk_permit_tone"));
    writeln("Keypad lock time: ", datafile.settings.get!string("keypad_lock_time"));
    */
    //writeln("Talk permit tone: ", datafile.settings.get("talk_permit_tone"));
    //writeln("Keypad lock time: ", datafile.settings.get("scan_digital_hangtime"));

    writeln("Text messages:");
    foreach(tm; datafile.textmessages.save) {
        writeln(tm);
    }

    writeln("Text messages:");
    foreach(tm; datafile.textmessages.save) {
        writeln(tm);
    }

    writeln("Updating text messages");
    datafile.textmessages.rows[1].message = "BOY HOWDY!";
    datafile.update_file(f, is_rdtfile);

    writeln("\nNew data class RS:");
    RS rs = new RS;
    writeln( rs.get("arbitrary") );

    
    writeln("\nNew data class RS_A:");
    RS_A rsa = new RS_A;
    rsa.load_from_mmap(datafile.settings);
    writeln( rsa.get("info_line1"));
    writeln( rsa.get("monitor_type"));
    writeln( rsa.get("radio_programming_password"));

    if (show_settings) {
        print_table(rsa, "Radio Settings");
    }

    if (dump_csv) {
        writeln("\nCSV conversion:");
        datafile.textmessages.to_csv("tms.csv");
        datafile.contacts.to_csv("contacts.csv");
        datafile.rxgroups.to_csv("rxgroups.csv");
        datafile.zones.to_csv("zones.csv");
        datafile.scanlists.to_csv("scanlists.csv");
        datafile.channels.to_csv("channels.csv");
    }

    return 0;
}
