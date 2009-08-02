/**
 * Copyright (C) 2009 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using GLib;

namespace FsoFramework
{
internal const string PROC_SELF_CMDLINE = "/proc/self/cmdline";

internal static SmartKeyFile _masterkeyfile = null;
internal static string _prefix = null;

internal static DBusServiceNotifier _dbusservicenotifier = null;

/**
 * @returns @a SmartKeyFile for frameworkd.conf
 **/
public static SmartKeyFile theMasterKeyFile()
{
    if ( _masterkeyfile == null )
    {
        _masterkeyfile = new SmartKeyFile();

        string[] locations = { "./frameworkd.conf",
                               "%s/.frameworkd.conf".printf( Environment.get_home_dir() ),
                               "/etc/frameworkd.conf" };

        foreach ( var location in locations )
        {
            if ( _masterkeyfile.loadFromFile( location ) )
            {
                message( "Using framework configuration file at '%s'", location );
                return _masterkeyfile;
            }
        }
        warning( "could not find framework configuration file." );
        return _masterkeyfile;
    }
    return _masterkeyfile;
}

/**
 * @returns @a Logger configured as requested in frameworkd.conf
 **/
public static Logger createLogger( string domain )
{
    return Logger.createFromKeyFile( theMasterKeyFile(), domain );
}

/**
 * Return the prefix for the running program.
 **/
public static string getPrefixForExecutable()
{
    if ( _prefix == null )
    {
        var cmd = FileHandling.read( PROC_SELF_CMDLINE );
        var pte = Environment.find_program_in_path( cmd );
        _prefix = "";

        foreach ( var component in pte.split( "/" ) )
        {
            //debug( "dealing with component '%s', prefix = '%s'", component, _prefix );
            if ( component == "bin" )
                break;
            _prefix += "%s%c".printf( component, Path.DIR_SEPARATOR );
        }
    }
    return _prefix;
}

/**
 * @returns @a DBusServiceNotifier
 **/
public static DBusServiceNotifier theDBusServiceNotifier()
{
    if ( _dbusservicenotifier == null )
    {
        _dbusservicenotifier = new DBusServiceNotifier();
    }
    return _dbusservicenotifier;
}


} /* namespace */