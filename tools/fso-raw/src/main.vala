/**
 * -- Mickey's DBus Utility V2 --
 *
 * Copyright (C) 2009 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 **/

//=========================================================================//
using GLib;

//=========================================================================//
const string FSO_USAGE_BUS   = "org.freesmartphone.ousaged";
const string FSO_USAGE_PATH  = "/org/freesmartphone/Usage";
const string FSO_USAGE_IFACE = "org.freesmartphone.Usage";

//=========================================================================//
MainLoop mainloop;

//=========================================================================//
class Commands : Object
{
    DBus.Connection bus;
    dynamic DBus.Object usage;

    public Commands()
    {
        try
        {
            bus = DBus.Bus.get( DBus.BusType.SYSTEM );
            usage = bus.get_object( FSO_USAGE_BUS, FSO_USAGE_PATH, FSO_USAGE_IFACE );
        }
        catch ( DBus.Error e )
        {
            critical( "dbus error: %s", e.message );
        }
    }

    public void listResources()
    {
        try
        {
            string[] res = usage.ListResources();
            foreach ( var r in res )
                stdout.printf( "%s\n", r );
        }
        catch ( DBus.Error e )
        {
            stderr.printf( "%s\n", e.message );
        }
    }

    public void allocateResources( string[] resources )
    {
        foreach ( var resource in resources )
        {
            try
            {
                usage.RequestResource( resource );
            }
            catch ( DBus.Error e )
            {
                if (force)
                    warning( "Could not request resource '%s': %s", resource, e.message );
                else
                    critical( "Could not request resource '%s' : %s", resource, e.message );
            }
        }
    }
}

//=========================================================================//
static bool listresources;
static bool force;
static bool timeout;
[NoArrayLength()]
static string[] resources;
[NoArrayLength()]
static string[] command;

const OptionEntry[] options =
{
    { "listresources", 'l', 0, OptionArg.NONE, ref listresources, "List resources (do not mix with -r)", null },
    { "resources", 'r', 0, OptionArg.STRING_ARRAY, ref resources, "Allocate resources during program execution", "RESOURCE..." },
    { "force", 'f', 0, OptionArg.NONE, ref force, "Continue execution, even if (some) resources can't be allocated.", null },
    { "timeout", 't', 0, OptionArg.INT, ref timeout, "Override default dbus timeout", "MSECS" },
    { "", 0, 0, OptionArg.FILENAME_ARRAY, ref command, null, "[--] COMMAND [ARGS]..." },
    { null }
};

//=========================================================================//
int main( string[] args )
{
    try
    {
        var opt_context = new OptionContext( "- FSO Resource Allocation Wrapper" );
        opt_context.set_help_enabled( true );
        opt_context.add_main_entries( options, null );
        opt_context.parse( ref args );
    }
    catch ( OptionError e )
    {
        stdout.printf( "%s\n", e.message );
        stdout.printf( "Run '%s --help' to see a full list of available command line options.\n", args[0] );
        return 1;
    }

    if ( listresources && resources != null )
    {
        stdout.printf( "ERROR: Listing resources is not possible in the same call as requesting resources.\n" );
        return 1;
    }

    if ( !listresources && resources == null )
    {
        stdout.printf( "ERROR: Either one of '-l' or '-r' must be supplied.\n" );
        return 1;
    }

    if ( resources != null && command == null )
    {
        stdout.printf( "ERROR: Need also a command when -r is supplied.\n" );
        return 1;
    }

    var commands = new Commands();
    if ( listresources )
    {
        commands.listResources();
        return 0;
    }

    // synthesize resource.length
    var i = 0;
    while ( resources[i] != null ) i++;
    resources.length = i;

    // also accept ',' form
    if ( resources.length == 1 && "," in resources[0] )
    {
        resources = resources[0].split( "," );
    }

    commands.allocateResources( resources );

    var child = Posix.fork();
    if ( child < 0 )
        critical( "Could not fork." );

    if ( child > 0 )
    {
        int status;
        var pid = Posix.wait( out status );
        return 0;
    }
    else
    {
        string cmdline = "";
        i = 0;
        while ( command[i++] != null )
        {
            cmdline += command[i-1];
            cmdline += " ";
        }
        return Posix.system( cmdline );
    }

    // rely on automatic resource cleanup

    return 0;
}

