/*
 * Copyright (C) 2010 Simon Busch <morphis@gravedo.de>
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
 
using FsoGsm;

public class MsmNetworkRegister : NetworkRegister
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        try 
        {
            var cmds = MsmModemAgent.instance().commands;
            cmds.change_operation_mode( Msmcomm.ModemOperationMode.ONLINE );
        }
        catch ( Msmcomm.Error err0 ) 
        {
            MsmUtil.handleMsmcommErrorMessage( err0 );
        }
        catch ( DBus.Error err1 )
        {
        }
    }
}

public class MsmNetworkGetSignalStrength : NetworkGetSignalStrength
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        signal = Msmcomm.RuntimeData.signal_strength;
    }
}

public class MsmNetworkGetStatus : NetworkGetStatus
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        status = new GLib.HashTable<string,Value?>( str_hash, str_equal );
        var strvalue = Value( typeof(string) );
        var intvalue = Value( typeof(int) );
        
        
        intvalue = Msmcomm.RuntimeData.signal_strength;
        status.insert( "strength", intvalue );
        
        // TODO:
        // - registration (network registration status: automatic, manual, unregister, unknown)
        // - mode (network registration mode: unregistered, home, searching, denied, roaming, unknown)
        // - lac
        // - cid (current call id?)
        // - act (Compact GSM, UMTS, EDGE, HSDPA, HSUPA, HSDPA/HSUPA, GSM)
        
        if ( Msmcomm.RuntimeData.functionality_status == Msmcomm.ModemOperationMode.ONLINE )
        {
            strvalue = Msmcomm.RuntimeData.current_operator_name;
            
            status.insert( "provider", strvalue );
            status.insert( "network", strvalue ); // base value
            status.insert( "display", strvalue ); // base value
            status.insert( "registration", Msmcomm.networkRegistrationStatusToString( Msmcomm.RuntimeData.network_reg_status ) );
        }
        else 
        {
            status.insert( "registration", "unregistered" );
        }
        
    }
}

public class MsmNetworkListProviders : NetworkListProviders
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        #if 0
        try
        {
            var ma = MsmModemAgent.instance();
            yield ma.commands.get_network_list();
            
            // NOTE: the following code block will handling the waiting for the 
            // unsolicited response NETWORK_LIST which transmits all available 
            // networks
            
            GLib.Variant v = yield ma.waitForUnsolicitedResponse( Msmcomm.UrcType.NETWORK_LIST );
            Msmcomm.NetworkProviderList nplist = Msmcomm.NetworkProviderList.from_variant( v );
            
            FreeSmartphone.GSM.NetworkProvider[] tmp = { };
            foreach( var provider in nplist.providers )
            {
                var p = FreeSmartphone.GSM.NetworkProvider("", "", provider.operator_name, "", "");
                tmp += p;
            }
            
            providers = tmp;
        }
        catch ( Msmcomm.Error err0 )
        {
            MsmUtil.handleMsmcommErrorMessage( err0 );
        }
        catch ( DBus.Error err1 )
        {
        }
        #endif
    }
}

public class MsmNetworkUnregister : NetworkUnregister
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        try 
        {
            var cmds = MsmModemAgent.instance().commands;
            cmds.change_operation_mode( Msmcomm.ModemOperationMode.OFFLINE );
        }
        catch ( Msmcomm.Error err0 ) 
        {
            MsmUtil.handleMsmcommErrorMessage( err0 );
        }
        catch ( DBus.Error err1 )
        {
        }
    }
}

public class MsmNetworkSendUssdRequest : NetworkSendUssdRequest
{
    public override async void run( string request ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        #if 0
        var cmd = theModem.createAtCommand<PlusCUSD>( "+CUSD" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.query( request ) );
        checkResponseOk( cmd, response );
        #endif
    }
}

public class MsmNetworkGetCallingId : NetworkGetCallingId
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        #if 0
        var cmd = theModem.createAtCommand<PlusCLIR>( "+CLIR" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );
        status = (FreeSmartphone.GSM.CallingIdentificationStatus) cmd.value;
        #endif
    }
}

public class MsmNetworkSetCallingId : NetworkSetCallingId
{
    public override async void run( FreeSmartphone.GSM.CallingIdentificationStatus status ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        #if 0
        var cmd = theModem.createAtCommand<PlusCLIR>( "+CLIR" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( status ) );
        checkResponseOk( cmd, response );
        #endif
    }
}
