/**
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

/**
 * @class MsmCommandHandler
 **/
public class MsmCommandHandler : FsoFramework.AbstractCommandHandler
{
    public unowned Msmcomm.Message command;
    public unowned Msmcomm.Message response;

    public MsmCommandHandler( Msmcomm.Message command, int retries )
    {
        this.command = command;
        this.retry = retries;
    }

    public override void writeToTransport( FsoFramework.Transport transport )
    {
        MsmCommandQueue.context.sendMessage( command );
    }

    public override string to_string()
    {
        if ( response != null )
        {
            return "\"%s\" -> %s".printf( Msmcomm.eventTypeToString( command.type ), Msmcomm.eventTypeToString( response.type ) );
        }
        else
        {
            return Msmcomm.eventTypeToString( command.type );
        }
    }
}

/**
 * @class MsmCommandQueue
 **/
public class MsmCommandQueue : FsoFramework.AbstractCommandQueue
{
    public static Msmcomm.Context context;

    protected override void onReadFromTransport( FsoFramework.Transport t )
    {
        context.readFromModem();
    }

    protected void onSolicitedResponse( MsmCommandHandler bundle, Msmcomm.Message response )
    {
        bundle.response = response;
        transport.logger.info( @"SRC: $bundle" );
        assert( bundle.callback != null );
        bundle.callback();
    }

    public async unowned Msmcomm.Message enqueueAsync( owned Msmcomm.Message command, int retries = DEFAULT_RETRY )
    {
        var handler = new MsmCommandHandler( command, retries );
        handler.callback = enqueueAsync.callback;
        enqueueCommand( handler );
        yield;
        return handler.response;
    }

    public void onMsmcommShouldRead( void* data, int len )
    {
        var bread = transport.read( data, len );
    }

    public void onMsmcommShouldWrite( void* data, int len )
    {
        var bwritten = transport.write( data, len );
        assert( bwritten == len );
    }

    public void onMsmcommGotEvent( int event, Msmcomm.Message message )
    {
        var et = Msmcomm.eventTypeToString( event );
        var size = message.size;
        var m = "ref %02x".printf( message.index );
        debug( @"[MESSAGE] $et $m " );
        var details = "";

        switch ( event )
        {
            case Msmcomm.ResponseType.GET_IMEI:
                unowned Msmcomm.Reply.GetImei msg = (Msmcomm.Reply.GetImei) message;
                details = @"IMEI = $(msg.getImei())";
                break;
            case Msmcomm.ResponseType.GET_FIRMWARE_INFO:
                // We want something like: var msg = message.safeCast<Msmcomm.Reply.GetImei>( message );
                unowned Msmcomm.Reply.GetFirmwareInfo msg = (Msmcomm.Reply.GetFirmwareInfo) message;
                details = @"FIRMWARE = $(msg.getInfo())";
                break;
            case Msmcomm.ResponseType.CM_CALL:
                unowned Msmcomm.Reply.Call msg = (Msmcomm.Reply.Call) message;
                details = @"refId = $(msg.index) cmd = $(msg.getCmd()) err = $(msg.getErrorCode())";
                break;
            case Msmcomm.ResponseType.CHARGER_STATUS:
                unowned Msmcomm.Reply.ChargerStatus msg = (Msmcomm.Reply.ChargerStatus) message;
                string mode = "<unknown>", voltage = "<unknown>";

                switch ( msg.mode )
                {
                    case Msmcomm.ChargingMode.USB:
                        mode = "USB";
                        break;
                    case Msmcomm.ChargingMode.INDUCTIVE:
                        mode = "INDUCTIVE";
                        break;
                    default:
                        mode = "UNKNOWN";
                        break;
                }

                switch ( msg.voltage )
                {
                    case Msmcomm.UsbVoltageMode.MODE_250mA:
                        voltage = "250mA";
                        break;
                    case Msmcomm.UsbVoltageMode.MODE_500mA:
                        voltage = "500mA";
                        break;
                    case Msmcomm.UsbVoltageMode.MODE_1A:
                        voltage = "1A";
                        break;
                    default:
                        voltage = "UNKNOWN";
                        break;
                }

                details = @"mode = $(mode) voltage = $(voltage)";
                break;
            default:
                break;
        }

        debug( @"$details" );

        if ( et.has_prefix( "RESPONSE" ) )
        {
            assert( current != null );
            onSolicitedResponse( (MsmCommandHandler)current, message );
            current = null;
            Idle.add( checkRestartingQ );
        }
        else
        {
            debug( @"FIXME: CREATE URC HANDLER FOR MSM COMMAND $et" );
        }
    }

    //
    // public API
    //
    public MsmCommandQueue( FsoFramework.Transport transport )
    {
        base( transport );
        context = new Msmcomm.Context();
    }

    public override bool open()
    {
        if ( base.open() )
        {
            context.registerEventHandler( onMsmcommGotEvent );
            context.registerReadHandler( onMsmcommShouldRead );
            context.registerWriteHandler( onMsmcommShouldWrite );

            var cmd = new Msmcomm.Command.ChangeOperationMode();
            cmd.setOperationMode( Msmcomm.OperationMode.RESET );
            context.sendMessage( cmd );

            return true;
        }

        return false;
    }
}

/**
 * @class MsmCommandSequence
 **/
public class MsmCommandSequence
{
    /*
    private string[] commands;

    public MsmCommandSequence( string[] commands )
    {
        this.commands = commands;
    }

    public void append( string[] commands )
    {
        foreach ( var cmd in commands )
        {
            this.commands += cmd;
        }
    }

    public async void performOnChannel( AtChannel channel )
    {
        foreach( var element in commands )
        {
            var cmd = theModem.createMsmCommand<CustomMsmCommand>( "CUSTOM" );
            var response = yield channel.enqueueAsync( cmd, element );
        }
    }
    */
}
