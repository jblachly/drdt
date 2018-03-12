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
    getopt(args, "infile|i", &infile);
    bool is_rdtfile;
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
    auto settings   = new RadioSettings[1];

    auto txtmsgs    = new TextMessage[50];
    auto contacts   = new ContactInformation[1000];
    auto rxgroups   = new RxGroup[250];
    auto zones      = new ZoneInfo[250]; 
    auto scanlists  = new ScanList[250];
    auto channels   = new ChannelInformation[1000];

    f.seek(0x2040 + (is_rdtfile ? rdt_headerlen : 0));
    f.rawRead(settings);

    f.seek(0x2180 + (is_rdtfile ? rdt_headerlen : 0));
    f.rawRead(txtmsgs);

    f.seek(0x5f80 + (is_rdtfile ? rdt_headerlen : 0));
    f.rawRead(contacts);

    f.seek(0xEC20 + (is_rdtfile ? rdt_headerlen : 0));
    f.rawRead(rxgroups);

    f.seek(84997);
    f.rawRead(zones);

    f.seek(100997);
    f.rawRead(scanlists);

    f.seek(127013);
    f.rawRead(channels);

    writeln(settings[0].info1.to!string);
    writeln(settings[0].info2.to!string);
    writeln(settings[0].radio_name.to!string);
    writeln("Talk permit tone: ", settings[0].talk_permit_tone);
    writeln("Keypad tones    : ", settings[0].keypad_tones);
    writeln("Intro screen: ", settings[0].intro_screen);
    writefln("DMR id: %d", settings[0].radio_dmr_id);
    //writefln("bit 568:%#x", settings[0].unknown_offset568);
    writefln("Radio programming password: [%s]", settings[0].radio_programming_password);

    foreach( c; contacts) {
        writeln("Contact name  : ", c.contact_name.to!string);
        writefln("Contact DMR id: %d", c.contact_dmr_id);
    }

    foreach( chan; channels ) {
        writeln( chan );
        writeln (chan.channel_name.to!string );
    }
    
    foreach( tm; txtmsgs) {
        writeln( tm);
        writeln("Empty? ", tm.empty);
    }
    */

/*
    writeln("Now trying OOP:");
    
    auto tms =      new Table!(TextMessage)(50, f, is_rdtfile);
    auto contacts = new Table!(ContactInformation)(1000);
    auto rxgroups = new Table!(RxGroup)(250);
    auto zones =    new Table!(ZoneInfo)(250);
    auto scanlists =new Table!(ScanList)(250);
    auto channels = new Table!(ChannelInformation)(1000);

    tms.load_from_file(f, is_rdtfile);
    foreach(tm; tms) {
        writeln(tm);
    }
    writeln("Done!");
    */

    writeln("Now with new class interface");

    MD380CodeplugFile datafile = new MD380CodeplugFile;
    datafile.load_from_file(f, is_rdtfile);

    writeln("Radio name: ", datafile.settings.radio_name.to!string);
    writeln("info1     : ", datafile.settings.info1.to!string);
    writeln("info2     : ", datafile.settings.info2.to!string);

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
