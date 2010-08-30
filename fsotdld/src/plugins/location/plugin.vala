/*
 * Copyright (C) 2009-2010 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

class Location.Service : FreeSmartphone.Location, FsoFramework.AbstractObject
{
    internal const string MODULE_NAME = "fsotdl.location";

    FsoFramework.Subsystem subsystem;
    private Gee.HashMap<string,FsoTdl.ILocationProvider> providers;

    construct
    {
        providers = new Gee.HashMap<string,FsoTdl.ILocationProvider>();
    }

    public Service( FsoFramework.Subsystem subsystem )
    {
        var tproviders = config.stringListValue( MODULE_NAME, "providers", {} );
        logger.debug( @"Will attempt to instantiate $(tproviders.length) location providers" );

        foreach ( var typename in tproviders )
        {
            var typ = Type.from_name( typename );
            if ( typ == Type.INVALID )
            {
                logger.error( @"Type $typename is invalid" );
                continue;
            }
            if ( !typ.is_a( typeof( FsoTdl.AbstractLocationProvider ) ) )
            {
                logger.error( @"Type $typename is not an FsoTdlAbstractLocationProvider" );
                continue;
            }
            var obj = Object.new( typ ) as FsoTdl.AbstractLocationProvider;
            obj.location.connect( onLocationUpdate );
            providers[ typ.name() ] = obj;
        }

        logger.info( "Ready." );

        Timeout.add_seconds( 2, () => {
            foreach ( var obj in providers.values )
            {
                obj.trigger();
            }
            return false;
        } );
    }

    public override string repr()
    {
        return @"<$(providers.size)>";
    }

    //
    // private API
    //
    private void onLocationUpdate( FsoTdl.ILocationProvider provider, HashTable<string,Value?> location )
    {
        debug( "got location update from %s", provider.repr() );
    }
}

Location.Service service;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    service = new Location.Service( subsystem );
    return Location.Service.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsotdl.location fso_register_function" );
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
