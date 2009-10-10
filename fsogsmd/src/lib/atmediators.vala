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

/**
 * This file contains Dbus/AT command mediators only using official 3GPP AT commands.
 *
 * Do _not_ add vendor-specific mediators here, instead add them to your modem plugin.
 **/

using Gee;

namespace FsoGsm {

/**
 * Some helper functions useful for mediators
 **/
internal async void gatherSpeakerVolumeRange()
{
    var data = theModem.data();
    if ( data.speakerVolumeMinimum == -1 )
    {
        var clvl = theModem.createAtCommand<PlusCLVL>( "+CLVL" );
        var response = yield theModem.processCommandAsync( clvl, clvl.test() );
        if ( clvl.validateTest( response ) == AtResponse.VALID )
        {
            data.speakerVolumeMinimum = clvl.min;
            data.speakerVolumeMaximum = clvl.max;
        }
        else
        {
            theModem.logger.warning( "Modem does not support querying volume range. Assuming (0-255)" );
            data.speakerVolumeMinimum = 0;
            data.speakerVolumeMaximum = 255;
        }
    }
}

internal async void gatherSimStatusAndUpdate()
{
    var data = theModem.data();

    var cmd = theModem.createAtCommand<PlusCPIN>( "+CPIN" );
    var response = yield theModem.processCommandAsync( cmd, cmd.query() );
    if ( cmd.validate( response ) == AtResponse.VALID )
    {
        if ( cmd.pin != data.simAuthStatus )
        {
            data.simAuthStatus = cmd.pin;
            //theModem.auth_status( cmd.pin );
            theModem.logger.info( "New SIM Auth status '%s'".printf( cmd.pin ) );
        }
    }
}

internal async void gatherListOfPhonebooks()
{
    var data = theModem.data();
    if ( data.simPhonebooks == null )
    {
        if ( data.simPhonebooks.length == 0 )
        {
            var cmd = theModem.createAtCommand<PlusCPBS>( "+CPBS" );
            var response = yield theModem.processCommandAsync( cmd, cmd.test() );
            if ( cmd.validateTest( response ) == AtResponse.VALID )
            {
                data.simPhonebooks = cmd.phonebooks;
            }
            else
            {
                theModem.logger.warning( "Modem does not support querying the phonebooks." );
            }
        }
    }
}

/**
 * Device Mediators
 **/
public class AtDeviceGetAntennaPower : DeviceGetAntennaPower
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cfun = theModem.createAtCommand<PlusCFUN>( "+CFUN" );
        var response = yield theModem.processCommandAsync( cfun, cfun.query() );
        checkResponseValid( cfun, response );
        antenna_power = cfun.value == 1;
    }
}

public class AtDeviceGetAlarmTime : DeviceGetAlarmTime
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var data = theModem.data();
        var cmd = theModem.createAtCommand<PlusCALA>( "+CALA" );
        var response = yield theModem.processCommandAsync( cmd, cmd.query() );
        // org.freesmartphone.Device.RealtimeClock can not throw a org.freesmartphone.GSM.Error,
        // hence we need to catch this error and transform it into something valid
        try
        {
            checkResponseValid( cmd, response );
        }
        catch ( FreeSmartphone.GSM.Error e )
        {
            throw new FreeSmartphone.Error.SYSTEM_ERROR( e.message );
        }
        // some modems strip the leading zero for one-digit chars, so we have to reassemble it
        var timestr = "%02d/%02d/%02d,%02d:%02d:%02d".printf( cmd.year, cmd.month, cmd.day, cmd.hour, cmd.minute, cmd.second );
        var formatstr = "%y/%m/%d,%H:%M:%S";
        var t = GLib.Time();
        t.strptime( timestr, formatstr );
        since_epoch = (int) Linux.timegm( t );

        if ( since_epoch == data.alarmCleared )
        {
            since_epoch = 0;
        }
    }
}

public class AtDeviceGetCurrentTime : DeviceGetCurrentTime
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = theModem.createAtCommand<PlusCCLK>( "+CCLK" );
        var response = yield theModem.processCommandAsync( cmd, cmd.query() );
        // org.freesmartphone.Device.RealtimeClock can not throw a org.freesmartphone.GSM.Error,
        // hence we need to catch this error and transform it into something valid
        try
        {
            checkResponseValid( cmd, response );
        }
        catch ( FreeSmartphone.GSM.Error e )
        {
            throw new FreeSmartphone.Error.SYSTEM_ERROR( e.message );
        }
        // some modems strip the leading zero for one-digit chars, so we have to reassemble it
        var timestr = "%02d/%02d/%02d,%02d:%02d:%02d".printf( cmd.year, cmd.month, cmd.day, cmd.hour, cmd.minute, cmd.second );
        var formatstr = "%y/%m/%d,%H:%M:%S";
        var t = GLib.Time();
        t.strptime( timestr, formatstr );
        since_epoch = (int) Linux.timegm( t );
    }
}

public class AtDeviceGetFunctionality : DeviceGetFunctionality
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cfun = theModem.createAtCommand<PlusCFUN>( "+CFUN" );
        var response = yield theModem.processCommandAsync( cfun, cfun.query() );
        checkResponseValid( cfun, response );
        level = Constants.instance().deviceFunctionalityStatusToString( cfun.value );
    }
}

public class AtDeviceGetInformation : DeviceGetInformation
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        info = new GLib.HashTable<string,Value?>( str_hash, str_equal );

        var value = Value( typeof(string) );

        var cgmr = theModem.createAtCommand<PlusCGMR>( "+CGMR" );
        var response = yield theModem.processCommandAsync( cgmr, cgmr.execute() );
        if ( cgmr.validate( response ) == AtResponse.VALID )
        {
            value = (string) cgmr.value;
            info.insert( "revision", value );
        }
        else
        {
            info.insert( "revision", "unknown" );
        }

        var cgmm = theModem.createAtCommand<PlusCGMM>( "+CGMM" );
        response = yield theModem.processCommandAsync( cgmm, cgmm.execute() );
        if ( cgmm.validate( response ) == AtResponse.VALID )
        {
            value = (string) cgmm.value;
            info.insert( "model", value );
        }
        else
        {
            info.insert( "model", "unknown" );
        }

        var cgmi = theModem.createAtCommand<PlusCGMI>( "+CGMI" );
        response = yield theModem.processCommandAsync( cgmi, cgmi.execute() );
        if ( cgmi.validate( response ) == AtResponse.VALID )
        {
            value = (string) cgmi.value;
            info.insert( "manufacturer", value );
        }
        else
        {
            info.insert( "manufacturer", "unknown" );
        }

        var cgsn = theModem.createAtCommand<PlusCGSN>( "+CGSN" );
        response = yield theModem.processCommandAsync( cgsn, cgsn.execute() );
        if ( cgsn.validate( response ) == AtResponse.VALID )
        {
            value = (string) cgsn.value;
            info.insert( "imei", value );
        }
        else
        {
            info.insert( "imei", "unknown" );
        }

        var cmickey = theModem.createAtCommand<PlusCMICKEY>( "+CMICKEY" );
        response = yield theModem.processCommandAsync( cmickey, cmickey.execute() );
        if ( cmickey.validate( response ) == AtResponse.VALID )
        {
            value = (string) cmickey.value;
            info.insert( "mickey", value );
        }
    }
}

public class AtDeviceGetFeatures : DeviceGetFeatures
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        features = new GLib.HashTable<string,Value?>( str_hash, str_equal );
        var value = Value( typeof(string) );

        var gcap = theModem.createAtCommand<PlusGCAP>( "+GCAP" );
        var response = yield theModem.processCommandAsync( gcap, gcap.execute() );
        if ( gcap.validate( response ) == AtResponse.VALID )
        {
            if ( "GSM" in gcap.value )
            {
                value = (string) "TA";
                features.insert( "gsm", value );
            }
        }

        var cgclass = theModem.createAtCommand<PlusCGCLASS>( "+CGCLASS" );
        response = yield theModem.processCommandAsync( cgclass, cgclass.test() );
        if ( cgclass.validateTest( response ) == AtResponse.VALID )
        {
            value = (string) cgclass.righthandside;
            features.insert( "gprs", value );
        }

        var fclass = theModem.createAtCommand<PlusFCLASS>( "+FCLASS" );
        response = yield theModem.processCommandAsync( fclass, fclass.test() );
        if ( fclass.validateTest( response ) == AtResponse.VALID )
        {
            value = (string) fclass.faxclass;
            features.insert( "fax", value );
        }
    }
}

public class AtDeviceGetMicrophoneMuted : DeviceGetMicrophoneMuted
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = theModem.createAtCommand<PlusCMUT>( "+CMUT" );
        var response = yield theModem.processCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );
        muted = cmd.value == 1;
    }
}

public class AtDeviceGetSimBuffersSms : DeviceGetSimBuffersSms
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = theModem.createAtCommand<PlusCNMI>( "+CNMI" );
        var response = yield theModem.processCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );
        buffers = cmd.mt < 2;
    }
}

public class AtDeviceGetSpeakerVolume : DeviceGetSpeakerVolume
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield gatherSpeakerVolumeRange();

        var cmd = theModem.createAtCommand<PlusCLVL>( "+CLVL" );
        var response = yield theModem.processCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );

        var data = theModem.data();
        volume = data.speakerVolumeMinimum + cmd.value * 100 / ( data.speakerVolumeMaximum - data.speakerVolumeMinimum );
    }
}

public class AtDeviceGetPowerStatus : DeviceGetPowerStatus
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = theModem.createAtCommand<PlusCBC>( "+CBC" );
        var response = yield theModem.processCommandAsync( cmd, cmd.execute() );

        checkResponseValid( cmd, response );
        status = cmd.status;
        level = cmd.level;
    }
}

public class AtDeviceSetAlarmTime : DeviceSetAlarmTime
{
    public override async void run( int since_epoch ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var data = theModem.data();
        var t = GLib.Time.gm( (time_t) since_epoch );

        var cmd = theModem.createAtCommand<PlusCALA>( "+CALA" );
        var response = yield theModem.processCommandAsync( cmd, since_epoch > 0 ? cmd.issue( t.year+1900-2000, t.month+1, t.day, t.hour, t.minute, t.second, 0 ) : cmd.clear() );

        // org.freesmartphone.Device.RealtimeClock can not throw a org.freesmartphone.GSM.Error,
        // hence we need to catch this error and transform it into something valid
        try
        {
            checkResponseOk( cmd, response );
        }
        catch ( FreeSmartphone.GSM.Error e )
        {
            throw new FreeSmartphone.Error.SYSTEM_ERROR( e.message );
        }
    }
}

public class AtDeviceSetCurrentTime : DeviceSetCurrentTime
{
    public override async void run( int since_epoch ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var t = GLib.Time.gm( (time_t) since_epoch );

        var cmd = theModem.createAtCommand<PlusCCLK>( "+CCLK" );
        var response = yield theModem.processCommandAsync( cmd, cmd.issue( t.year+1900-2000, t.month+1, t.day, t.hour, t.minute, t.second, 0 ) );

        // org.freesmartphone.Device.RealtimeClock can not throw a org.freesmartphone.GSM.Error,
        // hence we need to catch this error and transform it into something valid
        try
        {
            checkResponseOk( cmd, response );
        }
        catch ( FreeSmartphone.GSM.Error e )
        {
            throw new FreeSmartphone.Error.SYSTEM_ERROR( e.message );
        }
    }
}

public class AtDeviceSetFunctionality : DeviceSetFunctionality
{
    public override async void run( string level ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var value = Constants.instance().deviceFunctionalityStringToStatus( level );

        if ( value == -1 )
        {
            throw new FreeSmartphone.Error.INVALID_PARAMETER( "Functionality needs to be one of \"minimal\", \"airplane\", or \"full\"." );
        }

        var cmd = theModem.createAtCommand<PlusCFUN>( "+CFUN" );
        var response = yield theModem.processCommandAsync( cmd, cmd.issue( value ) );
        checkResponseOk( cmd, response );

        yield gatherSimStatusAndUpdate();
    }
}

public class AtDeviceSetMicrophoneMuted : DeviceSetMicrophoneMuted
{
    public override async void run( bool muted ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmut = theModem.createAtCommand<PlusCMUT>( "+CMUT" );
        var response = yield theModem.processCommandAsync( cmut, cmut.issue( muted ? 1 : 0 ) );

        checkResponseOk( cmut, response );
    }
}

public class AtDeviceSetSimBuffersSms : DeviceSetSimBuffersSms
{
    public override async void run( bool buffers ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        //if ( buffers != theModem.data().simBuffersSms )
        {
            var data = theModem.data();
            data.simBuffersSms = buffers;
            var cnmiparams = buffers ? data.cnmiSmsBufferedCb : data.cnmiSmsDirectCb;

            var cnmi = theModem.createAtCommand<PlusCNMI>( "+CNMI" );
            var response = yield theModem.processCommandAsync( cnmi, cnmi.issue( cnmiparams.mode,
                                                                                 cnmiparams.mt,
                                                                                 cnmiparams.bm,
                                                                                 cnmiparams.ds,
                                                                                 cnmiparams.bfr) );

            checkResponseOk( cnmi, response );
        }
    }
}

public class AtDeviceSetSpeakerVolume : DeviceSetSpeakerVolume
{
    public override async void run( int volume ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        if ( volume < 0 || volume > 100 )
        {
            throw new FreeSmartphone.Error.INVALID_PARAMETER( "Volume needs to be a percentage (0-100)" );
        }

        yield gatherSpeakerVolumeRange();

        var data = theModem.data();
        var value = data.speakerVolumeMinimum + volume * ( data.speakerVolumeMaximum - data.speakerVolumeMinimum ) / 100;

        var clvl = theModem.createAtCommand<PlusCLVL>( "+CLVL" );
        var response = yield theModem.processCommandAsync( clvl, clvl.issue( value ) );
        checkResponseOk( clvl, response );
    }
}

/**
 * SIM Mediators
 **/
public class AtSimListPhonebooks : SimListPhonebooks
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield gatherListOfPhonebooks();
        var data = theModem.data();
        phonebooks = data.simPhonebooks;
    }
}

/**
 * Network Mediators
 **/
public class AtNetworkListProviders : NetworkListProviders
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = theModem.createAtCommand<PlusCOPS>( "+COPS" );
        var response = yield theModem.processCommandAsync( cmd, cmd.test() );
        checkResponseOk( cmd, response );
        providers = cmd.providers;
    }
}

/**
 * Register all mediators
 **/
public void registerGenericAtMediators( HashMap<Type,Type> table )
{
    // register commands
    table[ typeof(DeviceGetAlarmTime) ]           = typeof( AtDeviceGetAlarmTime );
    table[ typeof(DeviceGetAntennaPower) ]        = typeof( AtDeviceGetAntennaPower );
    table[ typeof(DeviceGetCurrentTime) ]         = typeof( AtDeviceGetCurrentTime );
    table[ typeof(DeviceGetInformation) ]         = typeof( AtDeviceGetInformation );
    table[ typeof(DeviceGetFeatures) ]            = typeof( AtDeviceGetFeatures );
    table[ typeof(DeviceGetFunctionality) ]       = typeof( AtDeviceGetFunctionality );
    table[ typeof(DeviceGetMicrophoneMuted) ]     = typeof( AtDeviceGetMicrophoneMuted );
    table[ typeof(DeviceGetPowerStatus) ]         = typeof( AtDeviceGetPowerStatus );
    table[ typeof(DeviceGetSimBuffersSms) ]       = typeof( AtDeviceGetSimBuffersSms );
    table[ typeof(DeviceGetSpeakerVolume) ]       = typeof( AtDeviceGetSpeakerVolume );
    table[ typeof(DeviceSetAlarmTime) ]           = typeof( AtDeviceSetAlarmTime );
    table[ typeof(DeviceSetCurrentTime) ]         = typeof( AtDeviceSetCurrentTime );
    table[ typeof(DeviceSetFunctionality) ]       = typeof( AtDeviceSetFunctionality );
    table[ typeof(DeviceSetMicrophoneMuted) ]     = typeof( AtDeviceSetMicrophoneMuted );
    table[ typeof(DeviceSetSimBuffersSms) ]       = typeof( AtDeviceSetSimBuffersSms );
    table[ typeof(DeviceSetSpeakerVolume) ]       = typeof( AtDeviceSetSpeakerVolume );

    table[ typeof(SimListPhonebooks) ]            = typeof( AtSimListPhonebooks );

    table[ typeof(NetworkListProviders) ]         = typeof( AtNetworkListProviders );
}

} // namespace FsoGsm
