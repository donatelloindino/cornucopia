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

using Gee;

public delegate void UnsolicitedResponseHandlerFunc( string prefix, string rhs );
public delegate void UnsolicitedResponsePduHandlerFunc( string prefix, string rhs, string pdu );

class UnsolicitedResponseHandlerFuncWrapper
{
    public UnsolicitedResponseHandlerFunc func;
}

class UnsolicitedResponsePduHandlerFuncWrapper
{
    public UnsolicitedResponsePduHandlerFunc func;
}

/**
 * Unsolicited Interface, Base Class, and At Version
 **/

public abstract interface FsoGsm.UnsolicitedResponseHandler : FsoFramework.AbstractObject
{
    public abstract bool dispatch( string prefix, string rhs, string? pdu = null );
}

public class FsoGsm.BaseUnsolicitedResponseHandler : FsoGsm.UnsolicitedResponseHandler, FsoFramework.AbstractObject
{
    private HashMap<string,UnsolicitedResponseHandlerFuncWrapper> urcs;
    private HashMap<string,UnsolicitedResponsePduHandlerFuncWrapper> urcpdus;

    construct
    {
        urcs = new HashMap<string,UnsolicitedResponseHandlerFuncWrapper>();
        urcpdus = new HashMap<string,UnsolicitedResponsePduHandlerFuncWrapper>();
    }

    public override string repr()
    {
        return "";
    }

    protected void registerUrc( string prefix, UnsolicitedResponseHandlerFunc func )
    {
        urcs[prefix] = new UnsolicitedResponseHandlerFuncWrapper() { func=func };
    }

    protected void registerUrcPdu( string prefix, UnsolicitedResponsePduHandlerFunc func )
    {
        urcpdus[prefix] = new UnsolicitedResponsePduHandlerFuncWrapper() { func=func };
    }

    public bool dispatch( string prefix, string rhs, string? pdu = null )
    {
        if ( pdu == null )
        {
            var urcwrapper = urcs[prefix];
            if ( urcwrapper != null )
            {
                urcwrapper.func( prefix, rhs );
                return true;
            }
            else
            {
                return false;
            }
        }
        else
        {
            var urcwrapper = urcpdus[prefix];
            if ( urcwrapper != null )
            {
                urcwrapper.func( prefix, rhs, pdu );
                return true;
            }
            else
            {
                return false;
            }
        }
        return false; // not handled
    }
}

public class FsoGsm.AtUnsolicitedResponseHandler : FsoGsm.BaseUnsolicitedResponseHandler
{
    public AtUnsolicitedResponseHandler()
    {
        registerUrc( "+CALA", plusCALA );
        registerUrc( "+CIEV", plusCIEV );
    }

    public virtual void plusCALA( string prefix, string rhs )
    {
        // send dbus signal
        var obj = theModem.theDevice<FreeSmartphone.Device.RealtimeClock>();
        obj.alarm( 0 );
    }

    public virtual void plusCIEV( string prefix, string rhs )
    {
        logger.debug( "plusCIEV: %s %s".printf( prefix, rhs ) );
    }
}
