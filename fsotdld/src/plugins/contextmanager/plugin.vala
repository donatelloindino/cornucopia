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


namespace MyFreeSmartphone { namespace Context {

    [CCode (cheader_filename = "freesmartphone.h")]
    [DBus (timeout = 120000, name = "org.freesmartphone.Context.Manager")]
    public interface Manager : GLib.Object
    {
        public abstract async void subscribe_location_updates( BusName busname, FreeSmartphone.Context.LocationUpdateAccuracy desired_accuracy) throws FreeSmartphone.Error, GLib.DBusError, GLib.IOError;
        public abstract async void unsubscribe_location_updates( BusName busname ) throws FreeSmartphone.Error, GLib.DBusError, GLib.IOError;
    }
} /* namespace Context */
} /* namespace MyFreeSmartphone */

/**
 * @class Subscription
 *
 * Helper class encapsulating one client request
 **/
class Subscription : FsoFramework.AbstractObject
{
    public BusName busname;
    public FreeSmartphone.Context.LocationUpdateAccuracy accuracy;

    uint busnameWatchRef;

    public Subscription( BusName busname, FreeSmartphone.Context.LocationUpdateAccuracy accuracy )
    {
        this.busname = busname;
        this.accuracy = accuracy;

        busnameWatchRef = GLibHacks.Bus.watch_name( BusType.SYSTEM, busname, BusNameWatcherFlags.NONE, ( connection, name, owner ) => {}, ( connection, name ) => {
            assert( name == this.busname );
            service.handleDisappearingHandlerForSubscription( this );
        } );

        assert( logger.debug( "Created" ) );
    }

    public override string repr()
    {
        return @"<$busname>";
    }

    ~Subscription()
    {
        Bus.unwatch_name( busnameWatchRef );

        assert( logger.debug( "Destroyed" ) );
    }
}

/**
 * @class Context.Service
 *
 * DBus interface to the Context Manager
 **/
class Context.Service : MyFreeSmartphone.Context.Manager, FsoFramework.AbstractObject
{
    internal const string MODULE_NAME = "fsotdl.contextmanager";

    FsoFramework.Subsystem subsystem;
    private Gee.HashMap<string,FsoTdl.ILocationProvider> providers;
    private GLib.HashTable<string,GLib.Variant> status;

    private Gee.HashMap<string,Subscription> subscriptions;

    construct
    {
        providers = new Gee.HashMap<string,FsoTdl.ILocationProvider>();
        subscriptions = new Gee.HashMap<string,Subscription>();

        status = new GLib.HashTable<string,Variant>( GLib.str_hash, GLib.str_equal );
    }

    public Service( FsoFramework.Subsystem subsystem )
    {
        // scan for location providers
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

        subsystem.registerObjectForService<MyFreeSmartphone.Context.Manager>( FsoFramework.Context.ServiceDBusName, FsoFramework.Context.ManagerServicePath, this );

        logger.info( "Ready." );

        /*
        Timeout.add_seconds( 2, () => {
            foreach ( var obj in providers.values )
            {
                obj.trigger();
            }
            return false;
        } );
        */
    }

    public override string repr()
    {
        return @"<$(providers.size)>";
    }

    public void handleDisappearingHandlerForSubscription( Subscription s )
    {
        subscriptions.unset( s.busname.to_string() );
        subscriptionsHaveBeenUpdated();
    }

    //
    // private API
    //
    private void onLocationUpdate( FsoTdl.ILocationProvider provider, HashTable<string,Variant> location )
    {
        assert( logger.debug( @"Got location update from $(provider.get_type().name())" ) );
        status = location;
        //this.location_update( status ); // DBUS SIGNAL
    }

    private void mergeStatusAndSendSignal( HashTable<string,Variant> location )
    {
        location.get_keys().foreach( (key) => {
            status.insert( (string)key, location.lookup( (string)key ) );
        } );
        //this.location_update( status ); // DBUS SIGNAL
    }

    private void subscriptionsHaveBeenUpdated()
    {
        logger.debug( "..." );
    }

    //
    // org.freesmartphone.Location (DBus API)
    //
    public async void subscribe_location_updates( BusName busname, FreeSmartphone.Context.LocationUpdateAccuracy desired_accuracy ) throws FreeSmartphone.Error, GLib.DBusError, GLib.IOError
    {
        if ( desired_accuracy == 0 )
        {
            throw new FreeSmartphone.Error.INVALID_PARAMETER( "Please see documentation for allowed values" );
        }
        assert( logger.debug( @"$busname subscribes for location updates with desired accuracy $desired_accuracy" ) );

        var subscription = subscriptions[busname.to_string()];
        if ( subscription != null )
        {
            assert( logger.debug( @"Subscription for $busname already existing with accuracy $(subscription.accuracy); updating to accuracy $desired_accuracy" ) );
            subscription.accuracy = desired_accuracy;
        }
        else
        {
            subscriptions[busname.to_string()] = new Subscription( busname, desired_accuracy );
        }
        subscriptionsHaveBeenUpdated();

        // ...
    }

	public async void unsubscribe_location_updates( BusName busname ) throws FreeSmartphone.Error, GLib.DBusError, GLib.IOError
    {
        assert( logger.debug( @"$busname unsubscribes from location updates" ) );
        // ...
    }
}

internal Context.Service service;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    service = new Context.Service( subsystem );
    return Context.Service.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsotdl.contextmanager fso_register_function" );
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
