/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *                         Simon Busch <morphis@gravedo.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using GLib;
using FsoGsm;
using FsoFramework;

public class MsmChannel : CommandQueue, Channel, AbstractObject
{
    public Transport transport { get; set; }
    public string name;

    private FreeSmartphone.Usage usage;
    private bool is_initialized;
    private Msmcomm.ModemStatus currentModemStatus;
    private bool modem_lock_status;
    private uint modem_lock_count;

    public MsmUnsolicitedResponseHandler urc_handler;

    public Msmcomm.Management management_service;
    public Msmcomm.State state_service;
    public Msmcomm.Misc misc_service;
    public Msmcomm.Call call_service;
    public Msmcomm.Sim sim_service;
    public Msmcomm.Phonebook phonebook_service;
    public Msmcomm.Network network_service;

#if 0
    public void lockModem()
    {
        modem_lock_count++;
        modem_lock_status = true;
    }

    public void unlockModem();
    {
        if ( modem_lock_count > 0 )
        {
            modem_lock_count--;
        }
        else
        {
            logger.critical( "Someone calls unlockModem functionality without calling lockModem before!" );
        }

        modem_lock_status = modem_lock_count > 0;
    }

    public async void waitUntilModemIsUnlocked()
    {
    }
#endif

    private void onModemControlStatusChanged( Msmcomm.ModemStatus status )
    {
        currentModemStatus = status;

        /* ignore status updates as long as we are not initialized */
        if ( !is_initialized )
            return;

        switch ( status )
        {
            case Msmcomm.ModemStatus.ACTIVE:
                /* modem controller become active after it was successfully initialized?
                 * that can only one cause: modem was reseted due to internal error. We
                 * have to take care about this and re-synchronize with the modem.
                 */
                logger.error( "Modem control was reseted due to internal error; synchronizing with the modem ..." );

                Posix.sleep(2);
                misc_service.test_alive();

                break;
            case Msmcomm.ModemStatus.INACTIVE:
                break;
        }
    }

    public MsmChannel( string name )
    {
        urc_handler = new MsmUnsolicitedResponseHandler();

        is_initialized = false;
        currentModemStatus = Msmcomm.ModemStatus.UNKNOWN;

        this.name = name;
        theModem.registerChannel( name, this );
    }

    public bool is_ready()
    {
        return is_initialized;
    }

    public async bool open()
    {
        try
        {
            MsmData.reset();

            yield requestModemResource();

            /* initialize the modem controller itself */
            logger.debug( "Initialize modem controller ..." );
            yield management_service.initialize();

            /* wait as long as modem controller is not ready */
            logger.debug( "Waiting for modem controller to be fully initialized ..." );
            Timeout.add_seconds(2, () => {
                if ( currentModemStatus == Msmcomm.ModemStatus.ACTIVE )
                {
                    open.callback();
                    return false;
                }
                return true;
            });
            yield;

            urc_handler.setup();

            /* We sent here a test alive command to the modem to retrieve the response of
             * the change operation mode message after this. Never remove the delay! */
            yield misc_service.test_alive();
            Posix.sleep(2);

            /* reset the modem and wait for it to come back */
            logger.debug( "Reseting modem and waiting for it to come back ..." );
            yield state_service.change_operation_mode( Msmcomm.OperationMode.RESET );
            yield urc_handler.waitForUnsolicitedResponse( MsmUrcType.RESET_RADIO_IND );
            Posix.sleep(2);

            logger.debug( "Modem is back after reset now; Synchronizing ..." );
            yield misc_service.test_alive();

            is_initialized = true;
        }
        catch ( Msmcomm.Error err0 )
        {
        }
        catch ( GLib.Error err1 )
        {
        }

        return true;
    }

    public void injectResponse( string response )
    {
        assert_not_reached();
    }

    public async bool suspend()
    {
        return true;
    }

    public async bool resume()
    {
        return true;
    }

    private async bool requestModemResource()
    {
        try
        {
            usage = Bus.get_proxy_sync<FreeSmartphone.Usage>( BusType.SYSTEM, "org.freesmartphone.ousaged", "/org/freesmartphone/Usage" );
            yield usage.request_resource( "Modem" );
            registerObjects();
        }
        catch ( FreeSmartphone.UsageError err0  )
        {
            logger.error( @"Modem resource is not available: $(err0.message)" );
            return false;
        }
        catch ( GLib.Error err1 )
        {
        }

        return true;
    }

    private void registerObjects()
    {
        try 
        {
            management_service =  Bus.get_proxy_sync<Msmcomm.Management>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            management_service.modem_status.connect( onModemControlStatusChanged );
            misc_service =  Bus.get_proxy_sync<Msmcomm.Misc>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            state_service =  Bus.get_proxy_sync<Msmcomm.State>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            sim_service = Bus.get_proxy_sync<Msmcomm.Sim>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            phonebook_service = Bus.get_proxy_sync<Msmcomm.Phonebook>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            network_service = Bus.get_proxy_sync<Msmcomm.Network>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
            call_service = Bus.get_proxy_sync<Msmcomm.Call>( BusType.SYSTEM, "org.msmcomm", "/org/msmcomm" );
        }
        catch ( GLib.IOError err0 )
        {
        }
    }

    private async void releaseModemResource()
    {
        try
        {
            yield usage.release_resource( "Modem" );
        }
        catch ( FreeSmartphone.UsageError err0 )
        {
        }
        catch ( GLib.Error err1 )
        {
        }
    }

    public async void close()
    {
        try
        {
            logger.debug( "Shutdown modem controller ..." );
            yield management_service.shutdown();
            is_initialized = false;
        }
        catch ( Msmcomm.Error err0 )
        {
        }
        catch ( GLib.Error err1 )
        {
        }

        yield releaseModemResource();
    }

    public void registerUnsolicitedHandler( FsoFramework.CommandQueue.UnsolicitedHandler urchandler )
    {

    }

    public async void freeze( bool drain = false )
    {
    }

    public async void thaw()
    {
    }

    public override string repr()
    {
        return "<>";
    }
}

