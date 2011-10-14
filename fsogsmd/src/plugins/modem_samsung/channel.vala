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
    public SamsungIpc.Response response;

    public override void writeToTransport( FsoFramework.Transport t )
    {
        assert( theLogger.debug( @"Sending request with id = $(id), type = $(SamsungIpc.request_type_to_string(type)), " +
                                 @"command = $(SamsungIpc.command_type_to_string(command)), size = $(data.length)" ) );

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
    private new SamsungUnsolicitedResponseHandler urchandler;
    private uint8 current_request_id = 0;
    private Gee.LinkedList<CommandHandler> pending_requests;

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
                break;
            case FsoGsm.Modem.Status.ALIVE_SIM_READY:
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

        if ( fmtclient.recv(out response) == 0 )
            return;

        assert( theLogger.debug( @"Got response from modem: type = $(SamsungIpc.request_type_to_string(response.type)) " +
                                 @"command = $(SamsungIpc.command_type_to_string(response.command))" ) );

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
    }

    private void handle_solicited_response( SamsungIpc.Response response )
    {
        CommandHandler? request = null;

        foreach ( var preq in pending_requests )
        {
            if ( preq.id == response.aseq )
            {
                request = preq;
                break;
            }
        }

        if ( request == null )
        {
            theLogger.warning( @"Got response with id = $(response.aseq) which does not belong to any pending request!" );
            theLogger.warning( @"Ignoring response ..." );
            return;
        }

        request.callback();
    }

    protected override void onResponseTimeout( AbstractCommandHandler ach )
    {
        Samsung.CommandHandler handler = (Samsung.CommandHandler) ach;

        theLogger.warning( @"Command with id = $(handler.id) timed out while trying to send it to the modem!" );

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


    //
    // public API
    //

    public IpcChannel( string name, FsoFramework.Transport? transport )
    {
        base( transport );

        this.name = name;
        this.pending_requests = new Gee.LinkedList<CommandHandler>();

        theModem.registerChannel( name, this );
        theModem.signalStatusChanged.connect( onModemStatusChanged );

        fmtclient = new SamsungIpc.Client( SamsungIpc.ClientType.CRESPO_FMT );
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
    public async void enqueue_async( int type, int command, uint8[] data, out SamsungIpc.Response response, int retry = 0, int timeout = 0 )
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
        pending_requests.offer_tail( handler );

        yield;

        response = handler.response;
    }

    public void registerUnsolicitedHandler( UnsolicitedHandler urchandler ) { }

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
}

// vim:ts=4:sw=4:expandtab
