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

const string GsmDevice.MODULE_NAME = "fsogsm.gsm_device";

namespace GsmDevice
{

class Device : GLib.Object
{
    FsoFramework.Subsystem subsystem;
    static FsoFramework.Logger logger;

    public Device( FsoFramework.Subsystem subsystem )
    {
        if ( logger == null )
            logger = FsoFramework.createLogger( "fsogsm.gsm_device" );
        //logger.info( "created new Led for %s".printf( sysfsnode ) );

    }

}

} /* namespace */

List<GsmDevice.Device> instances;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    // scan sysfs path for leds
    var dir = new Dir( Kernel26.SYS_CLASS_LEDS );
    var entry = dir.read_name();
    while ( entry != null )
    {
        var filename = Path.build_filename( Kernel26.SYS_CLASS_LEDS, entry );
        instances.append( new Kernel26.Led( subsystem, filename ) );
        entry = dir.read_name();
    }
    return "fsodevice.kernel26_leds";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    debug( "yo" );
}

/**
 * This function gets called on plugin load time.
 * @return false, if the plugin operating conditions are present.
 * @note Some versions of glib contain a bug that leads to a SIGSEGV
 * in g_module_open, if you return true here.
 **/
/*public static bool g_module_check_init( void* m )
{
    var ok = FsoFramework.FileHandling.isPresent( Kernel26.SYS_CLASS_LEDS );
    return (!ok);
}
*/
