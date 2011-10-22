/*
 * Copyright (C) 2011 Simon Busch <morphis@gravedo.de>
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

public class Samsung.CommandHandler : FsoFramework.AbstractCommandHandler
{
    public unowned SamsungIpc.Client client;
    public uint8 id;
    public int type;
    public int command;
    public uint8[] data;
    public unowned SamsungIpc.Response response;
    public bool timed_out = false;

    public override void writeToTransport( FsoFramework.Transport t )
    {
        var message_type = (SamsungIpc.MessageType) command;
        assert( theLogger.debug( @"Sending request with id = $(id), type = $(SamsungIpc.request_type_to_string(type)), " +
                                 @"command = $(SamsungIpc.message_type_to_string(message_type)) (0x%04x), ".printf( command ) +
                                 @"size = $(data.length)" ) );

        assert( theLogger.debug( @"request data (length = $(data.length)):" ) );
        assert( theLogger.debug( FsoFramework.StringHandling.hexdump( data ) ) );

        client.send( command, type, data, id );
    }

    public override string to_string()
    {
        return @"";
    }
}

public class Samsung.IpcChannel : FsoGsm.Channel, FsoFramework.AbstractCommandQueue
{
    public string name;

    private SamsungIpc.Client fmtclient;
    private new Samsung.UnsolicitedResponseHandler urchandler;
    private uint8 current_request_id = 1;
    private bool initialized = false;

    public delegate void UnsolicitedHandler( string prefix, string response, string? pdu = null );

    /**
     * Generating a new request id. A valid request is in the range of 1 - 255.
     **/
    private uint8 next_request_id()
    {
        current_request_id = current_request_id >= 255 ? 1 : current_request_id++;
        return current_request_id;
    }

    private void onModemStatusChanged( FsoGsm.Modem modem, FsoGsm.Modem.Status status )
    {
        switch ( status )
        {
            case FsoGsm.Modem.Status.INITIALIZING:
                initialize();
                break;
            case FsoGsm.Modem.Status.ALIVE_SIM_READY:
                poweron();
                break;
            case FsoGsm.Modem.Status.CLOSING:
                break;
            default:
                break;
        }
    }

    protected override void onReadFromTransport( FsoFramework.Transport t )
    {
        SamsungIpc.Response response = SamsungIpc.Response();

        assert( theLogger.debug( @"Received data from modem; start processing ..." ) );

        var rc = fmtclient.recv(out response);
        if ( rc != 0 )
        {
            theLogger.error( @"Something went wrong while receiving data from the modem ... discarding this request!" );
            return;
        }

        var message_type = (SamsungIpc.MessageType) response.command;
        var response_type = (SamsungIpc.ResponseType) response.type;
        assert( theLogger.debug( @"Got response from modem: type = $(SamsungIpc.response_type_to_string(response_type)) " +
                                 @"command = $(SamsungIpc.message_type_to_string(message_type)) (0x%04x), ".printf( response.command )) );

        assert( theLogger.debug( @"response data (length = $(response.data.length)):" ) );
        assert( theLogger.debug( FsoFramework.StringHandling.hexdump( response.data ) ) );

        switch ( response.type )
        {
            case SamsungIpc.ResponseType.NOTIFICATION:
                urchandler.process( response );
                break;
            case SamsungIpc.ResponseType.INDICATION:
                break;
            case SamsungIpc.ResponseType.RESPONSE:
                handle_solicited_response( response );
                break;
        }

        // libsamsung-ipc allocates some memory for the response data which is not being
        // freed otherwise
        free(response.data);

        assert( theLogger.debug( @"Handled response from modem successfully!" ) );
    }

    private void handle_solicited_response( SamsungIpc.Response response )
    {
        var ch  = (Samsung.CommandHandler) current;

        if ( current == null || ch.id != response.aseq )
        {
            theLogger.warning( @"Got response with id = $(response.aseq) which does not belong to any pending request!" );
            theLogger.warning( @"Ignoring response ..." );
            return;
        }

        ch.response = response;
        ch.callback();
    }

    protected override void onResponseTimeout( AbstractCommandHandler ach )
    {
        Samsung.CommandHandler handler = (Samsung.CommandHandler) ach;

        theLogger.warning( @"Command with id = $(handler.id) timed out while trying to send it to the modem!" );
        handler.timed_out = true;

        // We're just telling the user about this as he will not receive any
        // response message for his enqueue_async call.
        handler.callback();
    }

    protected int modem_read_request(uint8[] data)
    {
        if ( data == null  )
            return 0;

        return transport.read(data, data.length);
    }

    protected int modem_write_request(uint8[] data)
    {
        if ( data == null )
            return 0;

        return transport.write(data, data.length);
    }

    private async void initialize()
    {
        unowned SamsungIpc.Response? response;

        // First we need to power on the modem so we can start working with it
        response = yield enqueue_async( SamsungIpc.RequestType.EXEC, SamsungIpc.MessageType.PWR_PHONE_STATE, new uint8[] { 0x2, 0x2 } );
        if ( response == null )
        {
            theLogger.error( @"Can't power up modem, could not send the command action for this!" );
            theModem.close();
            return;
        }

        assert( theLogger.debug( @"Powered up modem successfully!" ) );

        yield retrieveAndStoreBasebandSoftwareVersion();

        initialized = true;
    }

    private async void retrieveAndStoreBasebandSoftwareVersion()
    {
        unowned SamsungIpc.Response? response;

        response = yield enqueue_async( SamsungIpc.RequestType.GET, SamsungIpc.MessageType.MISC_ME_VERSION,
                                            new uint8[] { 0xff } );
        if ( response == null )
        {
            theLogger.error( @"Can't get baseband software version from modem!");
            return;
        }

        var message = (SamsungIpc.Misc.VersionMessage*) (response.data);

        assert( theLogger.debug( @"Baseband software version info:" ) );
        assert( theLogger.debug( @" sw_version = $((string) message.sw_version), hw_version = $((string) message.hw_version)" ) );
        assert( theLogger.debug( @" cal_date = $((string) message.cal_date)") );
        assert( theLogger.debug( @" misc = $((string) message.misc)") );
    }

    private async void poweron()
    {
        unowned SamsungIpc.Response? response;

        // FIXME why we send this requst is still unknown but we send it :)
        response = yield enqueue_async( SamsungIpc.RequestType.SET, SamsungIpc.MessageType.SMS_DEVICE_READY, new uint8[] { } );
    }

    //
    // public API
    //

    public IpcChannel( string name, FsoFramework.Transport? transport )
    {
        base( transport );

        this.name = name;
        this.urchandler = new Samsung.UnsolicitedResponseHandler();

        theModem.registerChannel( name, this );
        theModem.signalStatusChanged.connect( onModemStatusChanged );

        fmtclient = new SamsungIpc.Client( SamsungIpc.ClientType.CRESPO_FMT );
        fmtclient.set_log_handler( ( message ) => { theLogger.info( message ); } );
        fmtclient.set_delegates( modem_write_request, modem_read_request );
    }

    public override async bool open()
    {
        bool result = true;

        result = yield transport.openAsync();
        if (!result)
            return false;

        fmtclient.open();

        return true;
    }

    public override async void close()
    {
        fmtclient.close();
    }

    /**
     * Send a new response to the modem and wait until we get the response back.
     *
     * @param type Type of the request (see {@link SamsungIpc.RequestType})
     * @param command Type of the command we're sending
     * @param data Data of the request
     * @param retries Number of times the request should resend when sending fails
     * @param timeout Time to wait until the request receives (zero means an unlimited timeout)
     * @return Response message received for the request or null if sending is not possible or a timeout occured
     **/
    public async unowned SamsungIpc.Response? enqueue_async( int type, int command, uint8[] data = new uint8[] { },
                                                             int retry = 0, int timeout = 0 )
    {
        var handler = new Samsung.CommandHandler();

        handler.client = fmtclient;
        handler.id = next_request_id();
        handler.callback = enqueue_async.callback;
        handler.retry = retry;
        handler.timeout = timeout;
        handler.type = type;
        handler.command = command;
        handler.data = data;

        enqueueCommand( handler );
        yield;

        if ( handler.timed_out )
            return null;

        // reset current command handler so we're able to send more commands
        current = null;

        return handler.response;
    }

    public void registerUnsolicitedHandler( UnsolicitedHandler urchandler ) { }

    public void injectResponse( string response ) { assert_not_reached(); }

    public async bool suspend()
    {
        return true;
    }

    public async bool resume()
    {
        return true;
    }
}

// vim:ts=4:sw=4:expandtab
