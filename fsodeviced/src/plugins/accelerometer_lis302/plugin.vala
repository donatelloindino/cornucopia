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

namespace Hardware {

class AccelerometerLis302 : FsoDevice.BaseAccelerometer
{
    private string inputnode;
    private string sysfsnode;

    construct
    {
        logger.info( "Registering lis302 accelerometer" );
        // grab sysfs paths
        var sysfs_root = config.stringValue( "cornucopia", "sysfs_root", "/sys" );
        var devfs_root = config.stringValue( "cornucopia", "devfs_root", "/dev" );
        inputnode = config.stringValue( "cornucopia", "inputnode", "" );
    }

    public AccelerometerLis302()
    {
    }

    public override string repr()
    {
        return "<via %s>".printf( "unknown" );
    }
}

} /* namespace Hardware */

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    debug( "accelerometer_lis302 fso_factory_function" );
    return "fsodeviced.accelerometer_lis302";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    // do not remove this function
}
