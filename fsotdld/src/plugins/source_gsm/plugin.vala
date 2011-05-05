/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

using FsoTime;

namespace Source
{
    public const string MODULE_NAME_GSM = "source_gsm";
}

/**
 * @class Source.Gsm
 **/
class Source.Gsm : FsoTime.AbstractSource
{
    FreeSmartphone.GSM.Network ogsmd_device;
    FreeSmartphone.Data.World odatad_world;
    DBusService.IDBus dbus_dbus;

    construct
    {
        Idle.add( () => {
            initFromMainloop();
            return false;
        } );
    }

    private async void initFromMainloop()
    {
        DBusConnection conn = yield Bus.get( BusType.SYSTEM );

        ogsmd_device = yield conn.get_proxy<FreeSmartphone.GSM.Network>( FsoFramework.GSM.ServiceDBusName, FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );
        odatad_world = yield conn.get_proxy<FreeSmartphone.Data.World>( FsoFramework.Data.ServiceDBusName, FsoFramework.Data.WorldServicePath, DBusProxyFlags.DO_NOT_AUTO_START );
        dbus_dbus = yield conn.get_proxy<DBusService.IDBus>( DBusService.DBUS_SERVICE_DBUS, DBusService.DBUS_PATH_DBUS );

        //FIXME: Work around bug in Vala (signal handlers can't be async yet)
        ogsmd_device.status.connect( (status) => { onGsmNetworkStatusSignal( status ); } );
        ogsmd_device.time_report.connect( (time, zone) => { onGsmNetworkTimeReportSignal( time, zone ); } );

        yield triggerQueryAsync();
    }

    private void testing()
    {
        var status = new GLib.HashTable<string,GLib.Variant>( GLib.str_hash, GLib.str_equal );
        //status.insert( "code", "310038" );
        status.insert( "code", "26203" );
        onGsmNetworkStatusSignal( status );
    }

    public override string repr()
    {
        return "<>";
    }

    private bool arrayContainsElement( string[] array, string element )
    {
        for ( int i = 0; i < array.length; ++i )
        {
            if ( array[i] == element )
            {
                return true;
            }
        }
        return false;
    }

    private async void triggerQueryAsync()
    {
        // we don't want to autoactivate ogsmd, if it's not already present
        var names = yield dbus_dbus.ListNames();

        if ( arrayContainsElement( names, FsoFramework.GSM.ServiceDBusName ) )
        {
            try
            {
                var status = yield ogsmd_device.get_status();
                yield onGsmNetworkStatusSignal( status );
            }
            catch ( Error e )
            {
                logger.warning( @"Could not query the status from ogsmd: $(e.message)" );
            }
        }
        else
        {
            logger.warning( "ogsmd not present yet, waiting for signals..." );
        }
    }

    public override void triggerQuery()
    {
        triggerQueryAsync();
    }

    private async void onGsmNetworkStatusSignal( GLib.HashTable<string,GLib.Variant> status )
    {
        logger.info( "Received GSM network status signal" );

        Variant? codev = status.lookup( "code" );
        if ( codev == null )
        {
            logger.info( "No provider code contained, ignoring." );
            return;
        }
        var code = codev.get_string();

        string countrycode = "";
        GLib.HashTable<string,string> timezones = null;

        try
        {
            countrycode = yield odatad_world.get_country_code_for_mcc_mnc( code );
            timezones = yield odatad_world.get_timezones_for_country_code( countrycode );
        }
        catch ( Error e )
        {
            logger.warning( @"Could not query odatad: $(e.message)" );
            return;
        }

        var zonecount = timezones.size();

        logger.info( @"Resolved provider $code to country '$countrycode' w/ $zonecount timezone(s)" );
        if ( zonecount > 1 )
        {
            logger.info( @"Country has more than one timezone; not reporting change." );
            return;
        }

        this.reportZone( (string)timezones.get_values().nth_data(0), this ); // GOBJECT SIGNAL

        /*
         * Latitude and longitude of the zone's principal location
         * in ISO 6709 sign-degrees-minutes-seconds format,
         * either +-DDMM+-DDDMM or +-DDMMSS+-DDDMMSS,
         * first latitude (+ is north), then longitude (+ is east)
         */
        double lat = 0.0;
        double lon = 0.0;

        var coords = timezones.get_keys().nth_data(0);
        if ( coords.length == 11 ) // +-DDMM+-DDDMM
        {
            lat = coords.substring( 1, 4 ).to_double();
            lon = coords.substring( 6, 5 ).to_double();
            if ( coords[0] == '-' )
            {
                lat = -lat;
            }
            if ( coords[5] == '-' )
            {
                lon = -lon;
            }
            lat /= 100.0;
            lon /= 100.0;
        }
        else if ( coords.length == 15 ) // +-DDMMSS+-DDDMMSS
        {
            lat = coords.substring( 1, 6 ).to_double();
            lon = coords.substring( 8, 7 ).to_double();
            if ( coords[0] == '-' )
            {
                lat = -lat;
            }
            if ( coords[7] == '-' )
            {
                lon = -lon;
            }
            lat /= 10000.0;
            lon /= 10000.0;
        }
        else
        {
            logger.warning( @"Timezone lat/lon format unknown (length=$(coords.length))" );
            return;
        }

        this.reportLocation( lat, lon, 0, this ); // GOBJECT SIGNAL
    }

    private async void onGsmNetworkTimeReportSignal( int time, int zone )
    {
        logger.info( "Received GSM network time report signal" );

        // FIXME: Use signal to improve timezone value if we country spans multiple zones
    }
}

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    FsoFramework.theLogger.debug( "fsotdl.source_gsm fso_factory_function" );
    return Source.MODULE_NAME_GSM;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsotdl.source_gsm fso_register_function" );
    // do not remove this function
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

// vim:ts=4:sw=4:expandtab
