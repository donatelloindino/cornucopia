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

using Gee;
using FsoGsm;

/**
 * Public helpers
 **/
public void updateMsmSimAuthStatus( FreeSmartphone.GSM.SIMAuthStatus status )
{
    theModem.logger.info( @"SIM Auth status now $status" );

    // send the dbus signal
    var obj = theModem.theDevice<FreeSmartphone.GSM.SIM>();
    obj.auth_status( status );

    // check whether we need to advance the modem state
    var data = theModem.data();
    if ( status != data.simAuthStatus )
    {
        data.simAuthStatus = status;

        // advance global modem state
        var modemStatus = theModem.status();
        if ( modemStatus == Modem.Status.INITIALIZING )
        {
            if ( status == FreeSmartphone.GSM.SIMAuthStatus.READY )
            {
                theModem.advanceToState( Modem.Status.ALIVE_SIM_UNLOCKED );
            }
            else
            {
                theModem.advanceToState( Modem.Status.ALIVE_SIM_LOCKED );
            }
        }
        else if ( modemStatus == Modem.Status.ALIVE_SIM_LOCKED )
        {
            if ( status == FreeSmartphone.GSM.SIMAuthStatus.READY )
            {
                theModem.advanceToState( Modem.Status.ALIVE_SIM_UNLOCKED );
            }
        }
        else if ( modemStatus == Modem.Status.ALIVE_REGISTERED )
        {
            if ( status == FreeSmartphone.GSM.SIMAuthStatus.PIN_REQUIRED )
            {
                theModem.advanceToState( Modem.Status.ALIVE_SIM_LOCKED );
            }
        }
    }
}

/**
 * Modem facilities helpers
 **/
public async void gatherSimOperators() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
{
    /*
    var data = theModem.data();
    if ( data.simOperatorbook == null );
    {
        var copn = theModem.createAtCommand<PlusCOPN>( "+COPN" );
        var response = yield theModem.processAtCommandAsync( copn, copn.execute() );
        if ( copn.validateMulti( response ) == Constants.AtResponse.VALID )
        {
            data.simOperatorbook = copn.operators;
        }
        else
        {
            data.simOperatorbook = new GLib.HashTable<string,string>( GLib.str_hash, GLib.str_equal );
        }
    }
    */
}

static bool inGatherSimStatusAndUpdate;
static bool inTriggerUpdateNetworkStatus;

public async void gatherSimStatusAndUpdate() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
{
    if ( inGatherSimStatusAndUpdate )
    {
        assert( theModem.logger.debug( "already gathering sim status... ignoring additional trigger" ) );
        return;
    }
    inGatherSimStatusAndUpdate = true;

    yield gatherSimOperators();

#if 0
    var data = theModem.data();
    var cmd = theModem.createAtCommand<PlusCPIN>( "+CPIN" );
    var response = yield theModem.processAtCommandAsync( cmd, cmd.query() );
    var rcode = cmd.validate( response );
    if ( rcode == Constants.AtResponse.VALID )
    {
        theModem.logger.info( @"SIM Auth status $(cmd.status)" );
        // send the dbus signal
        var obj = theModem.theDevice<FreeSmartphone.GSM.SIM>();
        obj.auth_status( cmd.status );

        // check whether we need to advance the modem state
        if ( cmd.status != data.simAuthStatus )
        {
            data.simAuthStatus = cmd.status;

            // advance global modem state
            var modemStatus = theModem.status();
            if ( modemStatus >= Modem.Status.INITIALIZING && modemStatus <= Modem.Status.ALIVE_REGISTERED )
            {
                if ( cmd.status == FreeSmartphone.GSM.SIMAuthStatus.READY )
                {
                    theModem.advanceToState( Modem.Status.ALIVE_SIM_UNLOCKED, true );
                }
                else
                {
                    theModem.advanceToState( Modem.Status.ALIVE_SIM_LOCKED, true );
                }
            }
        }
    }
    else if ( rcode == Constants.AtResponse.CME_ERROR_010_SIM_NOT_INSERTED ||
              rcode == Constants.AtResponse.CME_ERROR_013_SIM_FAILURE )
    {
        theModem.logger.info( "SIM not inserted or broken" );
        theModem.advanceToState( Modem.Status.ALIVE_NO_SIM );
    }
    else
    {
        theModem.logger.warning( "Unhandled error while querying SIM PIN status" );
    }

#endif

    inGatherSimStatusAndUpdate = false;
}

/**
 * Update network status if something in network state has changed
 **/
public async void triggerUpdateNetworkStatus()
{
    if ( inTriggerUpdateNetworkStatus )
    {
        assert( theModem.logger.debug( "already gathering network status... ignoring additional trigger" ) );
        return;
    }
    inTriggerUpdateNetworkStatus = true;

    var mstat = theModem.status();

    // Ignore, if we don't have proper status to issue networking commands yet
    if ( mstat != Modem.Status.ALIVE_SIM_READY && mstat != Modem.Status.ALIVE_REGISTERED )
    {
        assert( theModem.logger.debug( @"triggerUpdateNetworkStatus() ignored while modem is in status $mstat" ) );
        inTriggerUpdateNetworkStatus = false;
        return;
    }


    // Advance modem status, if necessary
    if ( MsmData.network_info.reg_status == Msmcomm.NetworkRegistrationStatus.HOME  ||
         MsmData.network_info.reg_status == Msmcomm.NetworkRegistrationStatus.ROAMING )
    {
        if ( mstat != Modem.Status.ALIVE_REGISTERED )
        {
            theModem.advanceToState( Modem.Status.ALIVE_REGISTERED );
        }
    }

    // Send network status signal to connected clients
    var status = new GLib.HashTable<string,Variant>( str_hash, str_equal );
    fillNetworkStatusInfo( status );
    var obj = theModem.theDevice<FreeSmartphone.GSM.Network>();
    obj.status( status );

    inTriggerUpdateNetworkStatus = false;
}

/**
 * Register all mediators
 **/
public void registerMsmMediators( HashMap<Type,Type> table )
{
    table[ typeof(DebugCommand) ]                 = typeof( MsmDebugCommand );
    table[ typeof(DebugInjectResponse) ]          = typeof( MsmDebugInjectResponse );
    table[ typeof(DebugPing) ]                    = typeof( MsmDebugPing );

    table[ typeof(SimGetAuthCodeRequired) ]       = typeof( MsmSimGetAuthCodeRequired );
    table[ typeof(SimGetAuthStatus) ]             = typeof( MsmSimGetAuthStatus );
    table[ typeof(SimSendAuthCode) ]              = typeof( MsmSimSendAuthCode );
    table[ typeof(SimGetInformation) ]            = typeof( MsmSimGetInformation );
    table[ typeof(SimDeleteEntry) ]               = typeof( MsmSimDeleteEntry );
    table[ typeof(SimGetPhonebookInfo) ]          = typeof( MsmSimGetPhonebookInfo );
    table[ typeof(SimWriteEntry) ]                = typeof( MsmSimWriteEntry );
    table[ typeof(SimRetrievePhonebook) ]         = typeof( MsmSimRetrievePhonebook );
    table[ typeof(SimWriteEntry) ]                = typeof( MsmSimWriteEntry );
    table[ typeof(SimDeleteMessage) ]             = typeof( MsmSimDeleteMessage );
    table[ typeof(SimGetServiceCenterNumber) ]    = typeof( MsmSimGetServiceCenterNumber );
    table[ typeof(SimGetUnlockCounters) ]         = typeof( MsmSimGetUnlockCounters );
    table[ typeof(SimRetrieveMessage) ]           = typeof( MsmSimRetrieveMessage );
    table[ typeof(SimSendStoredMessage) ]         = typeof( MsmSimSendStoredMessage );
    table[ typeof(SimSetServiceCenterNumber) ]    = typeof( MsmSimSetServiceCenterNumber );
    table[ typeof(SimStoreMessage) ]              = typeof( MsmSimStoreMessage );
    table[ typeof(SimUnlock) ]                    = typeof( MsmSimUnlock );
    table[ typeof(SimChangeAuthCode) ]            = typeof( MsmSimChangeAuthCode );

    table[ typeof(DeviceGetFeatures) ]            = typeof( MsmDeviceGetFeatures );
    table[ typeof(DeviceGetInformation) ]         = typeof( MsmDeviceGetInformation );
    table[ typeof(DeviceGetFunctionality) ]       = typeof( MsmDeviceGetFunctionality );
    table[ typeof(DeviceGetPowerStatus) ]         = typeof( MsmDeviceGetPowerStatus );
    table[ typeof(DeviceSetFunctionality) ]       = typeof( MsmDeviceSetFunctionality );
    table[ typeof(DeviceGetCurrentTime) ]         = typeof( MsmDeviceGetCurrentTime );
    table[ typeof(DeviceSetCurrentTime) ]         = typeof( MsmDeviceSetCurrentTime );
    table[ typeof(DeviceGetAlarmTime) ]           = typeof( MsmDeviceGetAlarmTime );
    table[ typeof(DeviceGetMicrophoneMuted) ]     = typeof( MsmDeviceGetMicrophoneMuted );
    table[ typeof(DeviceGetSimBuffersSms) ]       = typeof( MsmDeviceGetSimBuffersSms );
    table[ typeof(DeviceGetSpeakerVolume) ]       = typeof( MsmDeviceGetSpeakerVolume );
    table[ typeof(DeviceSetAlarmTime) ]           = typeof( MsmDeviceSetAlarmTime );
    table[ typeof(DeviceSetMicrophoneMuted) ]     = typeof( MsmDeviceSetMicrophoneMuted );
    table[ typeof(DeviceSetSpeakerVolume) ]       = typeof( MsmDeviceSetSpeakerVolume );

    table[ typeof(NetworkRegister) ]              = typeof( MsmNetworkRegister );
    table[ typeof(NetworkUnregister) ]            = typeof( MsmNetworkUnregister );
    table[ typeof(NetworkGetStatus) ]             = typeof( MsmNetworkGetStatus );
    table[ typeof(NetworkGetSignalStrength) ]     = typeof( MsmNetworkGetSignalStrength );
    table[ typeof(NetworkListProviders) ]         = typeof( MsmNetworkListProviders );
    table[ typeof(NetworkSetCallingId) ]          = typeof( MsmNetworkSetCallingId );
    table[ typeof(NetworkGetCallingId) ]          = typeof( MsmNetworkGetCallingId );
    table[ typeof(NetworkSendUssdRequest) ]       = typeof( MsmNetworkSendUssdRequest );

    table[ typeof(CallActivate) ]                 = typeof( MsmCallActivate );
    table[ typeof(CallHoldActive) ]               = typeof( MsmCallHoldActive );
    table[ typeof(CallInitiate) ]                 = typeof( MsmCallInitiate );
    table[ typeof(CallListCalls) ]                = typeof( MsmCallListCalls );
    table[ typeof(CallReleaseAll) ]               = typeof( MsmCallReleaseAll );
    table[ typeof(CallRelease) ]                  = typeof( MsmCallRelease );
    table[ typeof(CallSendDtmf) ]                 = typeof( MsmCallSendDtmf );

    table[ typeof(SmsRetrieveTextMessages) ]      = typeof( MsmSmsRetrieveTextMessages );
    table[ typeof(SmsGetSizeForTextMessage) ]     = typeof( MsmSmsGetSizeForTextMessage );
    table[ typeof(SmsSendTextMessage) ]           = typeof( MsmSmsSendTextMessage );

    table[ typeof(CbSetCellBroadcastSubscriptions) ] = typeof( MsmCbSetCellBroadcastSubscriptions );
    table[ typeof(CbGetCellBroadcastSubscriptions) ] = typeof( MsmCbGetCellBroadcastSubscriptions );

    table[ typeof(MonitorGetServingCellInformation) ] = typeof( MsmMonitorGetServingCellInformation );
    table[ typeof(MonitorGetNeighbourCellInformation) ] = typeof( MsmMonitorGetNeighbourCellInformation );

    table[ typeof(VoiceMailboxGetNumber) ]        = typeof( MsmVoiceMailboxGetNumber );
    table[ typeof(VoiceMailboxSetNumber) ]        = typeof( MsmVoiceMailboxSetNumber );
}
