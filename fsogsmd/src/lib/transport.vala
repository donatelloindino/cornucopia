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

namespace FsoGsm
{
    public const int MUX_TRANSPORT_MAX_BUFFER = 1024;
}

//===========================================================================
public class FsoGsm.LibGsm0710muxTransport : FsoFramework.BaseTransport
//===========================================================================
{
    static Gsm0710mux.Manager manager;
    private Gsm0710mux.ChannelInfo channelinfo;
    private FsoFramework.DelegateTransport tdelegate;

    private char[] buffer;
    private int length;

    static construct
    {
        manager = new Gsm0710mux.Manager();
    }

    public LibGsm0710muxTransport( int channel = 0 )
    {
        base( "LibGsm0710muxTransport" );

        buffer = new char[1024];
        length = 0;

        var version = manager.getVersion();
        var hasAutoSession = manager.hasAutoSession();
        assert( hasAutoSession ); // we do not support non-autosession yet

        tdelegate = new FsoFramework.DelegateTransport(
                                                      delegateWrite,
                                                      delegateRead,
                                                      delegateHup,
                                                      delegateOpen,
                                                      delegateClose,
                                                      delegateFreeze,
                                                      delegateThaw );

        channelinfo.tspec = FsoFramework.TransportSpec( "foo", "bar" );
        channelinfo.tspec.transport = tdelegate;
        channelinfo.number = channel;
        channelinfo.consumer = "fsogsmd";

        logger.debug( "Created. Using libgsm0710mux version %s; autosession is %s".printf( version, hasAutoSession.to_string() ) );
    }

    public override bool open()
    {
        try
        {
            manager.allocChannel( ref channelinfo );
        }
        catch ( FsoFramework.TransportError e )
        {
            debug( "error: %s", e.message );
            return false;
        }

        return true;
    }

    public override int read( void* data, int length )
    {
        assert( this.length > 0 );
        assert( this.length < length );
        GLib.Memory.copy( data, this.buffer, this.length );
        message( @"READ %d from MUX: %s", length, ((string)data).escape( "" ) );
        var l = this.length;
        this.length = 0;
        return l;
    }

    public override int write( void* data, int length )
    {
        assert( this.length == 0 ); // NOT REENTRANT!
        assert( length < MUX_TRANSPORT_MAX_BUFFER );
        message( @"WRITE %d to MUX: %s", length, ((string)data).escape( "" ) );
        this.length = length;
        GLib.Memory.copy( this.buffer, data, length );
        tdelegate.readfunc( tdelegate );
        assert( this.length == 0 ); // everything has been consumed
        return length;
    }

    public override void freeze()
    {
    }

    public override void thaw()
    {
    }

    public override string repr()
    {
        return "<LibGsm0710muxFsoFramework.Transport>";
    }

    //
    // delegate transport interface
    //
    public bool delegateOpen( FsoFramework.Transport t )
    {
        message( "FROM MODEM OPEN ACK" );
        return true;
    }

    public void delegateClose( FsoFramework.Transport t )
    {
        message( "FROM MODEM CLOSE REQ" );
    }

    public int delegateWrite( void* data, int length, FsoFramework.Transport t )
    {
        assert( this.length == 0 );
        message( "FROM MODEM WRITE %d bytes", length );
        assert( length < MUX_TRANSPORT_MAX_BUFFER );
        GLib.Memory.copy( this.buffer, data, length ); // prepare data
        this.length = length;
        this.readfunc( this ); // signalize data being available
        assert( this.length == 0 ); // all has been consumed
        return length;
    }

    public int delegateRead( void* data, int length, FsoFramework.Transport t )
    {
        assert( this.length > 0 );
        message( "FROM MODEM READ %d bytes", length );
        assert( length > this.length );
        GLib.Memory.copy( data, this.buffer, this.length );
        var l = this.length;
        this.length = 0;
        return l;
    }

    public void delegateHup( FsoFramework.Transport t )
    {
        message( "FROM MODEM HUP" );
    }

    public void delegateFreeze( FsoFramework.Transport t )
    {
        message( "FROM MODEM FREEZE REQ" );
    }

    public void delegateThaw( FsoFramework.Transport t )
    {
        message( "FROM MODEM THAW REQ" );
    }
}
