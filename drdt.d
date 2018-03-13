import std.bitmanip;
import std.file;
import std.stdio;
import std.conv;
import std.string : lastIndexOf;
import std.getopt;

import radiodata;
import radiodatafile;

// http://forum.dlang.org/thread/eiquqszzycomrcazcfsb@forum.dlang.org
// http://www.iz2uuf.net/wp/index.php/2016/06/04/tytera-dm380-codeplug-binary-format/



int main(string[] args) {

    string infile;
    bool is_rdtfile;
    getopt(args, "infile|i", &infile);
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
    auto f = File(infile);

    /*
    writeln(settings[0].info1.to!string);
    writeln(settings[0].info2.to!string);
    writeln(settings[0].radio_name.to!string);
    writeln("Talk permit tone: ", settings[0].talk_permit_tone);
    writeln("Keypad tones    : ", settings[0].keypad_tones);
    writeln("Intro screen: ", settings[0].intro_screen);
    writefln("DMR id: %d", settings[0].radio_dmr_id);
    writefln("Radio programming password: [%s]", settings[0].radio_programming_password);
    */

    writeln("Now with new class interface");

    MD380CodeplugFile datafile = new MD380CodeplugFile;
    datafile.load_from_file(f, is_rdtfile);

    writeln("Radio name: ", datafile.settings.radio_name.to!string);
    writeln("info1     : ", datafile.settings.info1.to!string);
    writeln("info2     : ", datafile.settings.info2.to!string);

    writeln("Now trying getters / setters:");
    writeln("scan_digital_hangtime: ", datafile.settings.description["scan_digital_hangtime"]);
    writeln("scan_digital_hangtime: ", datafile.settings.get("scan_digital_hangtime"));

    writeln("Text messages:");
    foreach(tm; datafile.textmessages.save) {
        writeln(tm);
    }

    writeln("Text messages:");
    foreach(tm; datafile.textmessages.save) {
        writeln(tm);
    }

    f.close();
    return 0;
}
