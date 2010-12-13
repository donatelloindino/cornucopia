/*
 * Copyright (C) 2010 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

namespace N900
{

/**
 * Bluetooth power control for Nokia N900
 **/
class BluetoothPowerControl : FsoDevice.BasePowerControl
{
    private FsoFramework.Subsystem subsystem;
    private string sysfsnode;
    private string name;

    public BluetoothPowerControl( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        base( Path.build_filename( sysfsnode, "power_on" ) );
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;
        this.name = Path.get_basename( sysfsnode );


        subsystem.registerServiceName( FsoFramework.Device.ServiceDBusName );
        subsystem.registerServiceObject( FsoFramework.Device.ServiceDBusName,
                                         "%s/%u".printf( FsoFramework.Device.PowerControlServicePath, counter++ ),
                                         this );


        logger.info( "created." );
    }
}

/**
 * UsbHost mode control for N900 GTA02
 **/
class UsbHostModeControl : FsoDevice.BasePowerControl
{
    private FsoFramework.Subsystem subsystem;
    private string sysfsnode;
    private string umodenode;
    private string name;

    public UsbHostModeControl( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        base( Path.build_filename( sysfsnode, "power_on" ) );
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;
        this.umodenode = Path.build_filename( sysfs_root, "devices", "platform", "s3c2410-ohci", "usb_mode" );
        this.name = Path.get_basename( sysfsnode );

        subsystem.registerServiceName( FsoFramework.Device.ServiceDBusName );
        subsystem.registerServiceObject( FsoFramework.Device.ServiceDBusName,
                                         "%s/%u".printf( FsoFramework.Device.PowerControlServicePath, counter++ ),
                                                 this );

        logger.info( "created." );
    }

    public override bool getPower()
    {
        return false;
    }

    public override void setPower( bool on )
    {
    }
}

/**
 * WiFi power control for Nokia N900
 **/
class WiFiPowerControl : FsoDevice.BasePowerControl
{
    private FsoFramework.Subsystem subsystem;
    private string sysfsnode;
    private string name;

    public WiFiPowerControl( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        base( Path.build_filename( sysfsnode, null ) );
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;
        this.name = Path.get_basename( sysfsnode );

        subsystem.registerServiceName( FsoFramework.Device.ServiceDBusName );
        subsystem.registerServiceObject( FsoFramework.Device.ServiceDBusName,
                                         "%s/%u".printf( FsoFramework.Device.PowerControlServicePath, counter++ ),
                                                 this );

        logger.info( "created." );
    }

    public override bool getPower()
    {
        return false;
    }

    public override void setPower( bool on )
    {
    }
}

} /* namespace */

internal List<FsoDevice.BasePowerControlResource> resources;
internal List<FsoDevice.BasePowerControl> instances;
internal static string sysfs_root;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    // grab sysfs paths
    var config = FsoFramework.theConfig;
    sysfs_root = config.stringValue( "cornucopia", "sysfs_root", "/sys" );
    var devices = Path.build_filename( sysfs_root, "bus", "platform", "devices" );
    var drivers = Path.build_filename( sysfs_root, "bus", "platform", "drivers" );

    var bto = new N900.BluetoothPowerControl( subsystem, "/" );
    instances.append( bto );
#if WANT_FSO_RESOURCE
    resources.append( new FsoDevice.BasePowerControlResource( bto, "Bluetooth", subsystem ) );
#endif

    var wifio = new N900.WiFiPowerControl( subsystem, "/" );
    instances.append( wifio );
#if WANT_FSO_RESOURCE
    resources.append( new FsoDevice.BasePowerControlResource( wifio, "WiFi", subsystem ) );
#endif

    //TODO: add other devices

    return "fsodevice.n900_powercontrol";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsodevice.n900_powercontrol fso_register_function()" );
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
