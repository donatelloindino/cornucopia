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
    public SamsungIpc.RequestType request_type;
    public SamsungIpc.MessageType message_type;
    public uint8[] data;
    public unowned SamsungIpc.Response response;
    public bool timed_out = false;

    public override void writeToTransport( FsoFramework.Transport t )
    {
        assert( theLogger.debug( @"Sending request with id = $(id), request_type = $(request_type), " +
                                 @"message_type = $(message_type) " ) );

        assert( theLogger.debug( @"request data (length = $(data.length)):" ) );
        assert( theLogger.debug( "\n" + FsoFramework.StringHandling.hexdump( data ) ) );

        client.send( message_type, request_type, data, id );
    }

    public override string to_string()
    {
        return @"<>";
    }
}

public class Samsung.IpcChannel : FsoGsm.Channel, FsoFramework.AbstractCommandQueue
{
    public string name;

    private SamsungIpc.Client fmtclient;
    public new Samsung.UnsolicitedResponseHandler urchandler;
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

        assert( theLogger.debug( @"Got response from modem: type = $(response.type), command = $(response.command)" ) );
        assert( theLogger.debug( @"response data (length = $(response.data.length)):" ) );
        assert( theLogger.debug( "\n" + FsoFramework.StringHandling.hexdump( response.data ) ) );

        switch ( response.type )
        {
            case SamsungIpc.ResponseType.NOTI:
                urchandler.process( response );
                break;
            case SamsungIpc.ResponseType.INDI:
                break;
            case SamsungIpc.ResponseType.RESP:
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
        resetTimeout();

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
        Idle.add( () => { handler.callback(); return false; } );
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

        initialized = true;
    }

    private async void poweron()
    {
        unowned SamsungIpc.Response? response;

        // FIXME why we send this requst is still unknown but we send it :)
        response = yield enqueue_async( SamsungIpc.RequestType.SET, SamsungIpc.MessageType.SMS_DEVICE_READY );

        // We need to read the name of our network provider from the SIM card
        var rsimreq = SamsungIpc.Security.RSimAccessRequestMessage();
        rsimreq.command = SamsungIpc.Security.RSimCommandType.READ_BINARY;
        rsimreq.fileid = (uint16) Constants.instance().simFilesystemEntryNameToCode( "EFspn" );

        response = yield enqueue_async( SamsungIpc.RequestType.GET, SamsungIpc.MessageType.SEC_RSIM_ACCESS, rsimreq.data );

        if ( response == null )
        {
            theLogger.error( @"Could not retrieve provider name from SIM!" );
            return;
        }

        ModemState.sim_provider_name = SamsungIpc.Security.RSimAccessResponseMessage.get_file_data( response );
        assert( theLogger.debug( @"Got the following provider name from SIM card spn = $(ModemState.sim_provider_name)" ) );

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

        fmtclient = new SamsungIpc.Client( SamsungIpc.ClientType.FMT );
        fmtclient.set_log_handler( ( message ) => { theLogger.info( message ); } );
        fmtclient.set_io_handlers( modem_read_request, modem_write_request );
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
    public async unowned SamsungIpc.Response? enqueue_async( SamsungIpc.RequestType type, SamsungIpc.MessageType command, uint8[] data = new uint8[] { },
                                                             int retry = 0, int timeout = 5 )
    {
        var handler = new Samsung.CommandHandler();

        handler.client = fmtclient;
        handler.id = next_request_id();
        handler.callback = enqueue_async.callback;
        handler.retry = retry;
        handler.timeout = timeout;
        handler.message_type = command;
        handler.request_type = type;
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
