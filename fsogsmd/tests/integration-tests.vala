/*
 * (C) 2011-2012 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 */

using GLib;
using FsoFramework;
using FsoFramework.Test;

namespace FsoTest
{
    public const string FREESMARTPHONE_ERROR_DOMAIN = "free_smartphone_error-quark";
}

[DBus (name = "org.ofono.phonesim.Error")]
public errordomain PhonesimError
{
    [DBus (name = "FileNotFound")]
    FILE_NOT_FOUND,
    [DBus (name = "ScriptExecError")]
    SCRIPT_EXEC_ERROR,
}

[DBus (name = "org.ofono.phonesim.Script", timeout = 120000)]
public interface IPhonesimService : GLib.Object
{
    [DBus (name = "SetPath")]
    public abstract async void set_path( string path ) throws GLib.IOError, GLib.DBusError, PhonesimError;
    [DBus (name = "GetPath")]
    public abstract async string get_path() throws GLib.IOError, GLib.DBusError, PhonesimError;
    [DBus (name = "Run")]
    public abstract async string run( string name ) throws GLib.IOError, GLib.DBusError, PhonesimError;
}

public interface IRemotePhoneControl : GLib.Object
{
    public abstract async void initiate_call( string number, bool hide ) throws RemotePhoneControlError;
    public abstract async void activate_incoming_call( int id ) throws RemotePhoneControlError;

}

public errordomain RemotePhoneControlError
{
    FAILED,
}

public class PhonesimRemotePhoneControl : FsoFramework.AbstractObject, IRemotePhoneControl
{
    private IPhonesimService _phonesim;
    private string _script_path;

    //
    // private
    //

    private async void ensure_connection() throws RemotePhoneControlError
    {
        if ( _phonesim != null )
            return;

        try
        {
            _phonesim = yield GLib.Bus.get_proxy<IPhonesimService>( BusType.SESSION, "org.ofono.phonesim", "/" );
            yield _phonesim.set_path( _script_path );
        }
        catch ( GLib.Error error )
        {
            throw new RemotePhoneControlError.FAILED( @"Failed to establish a connection to the phonesim service: $(error.message)" );
        }
    }

    private async void execute_script( string script ) throws RemotePhoneControlError
    {
        string path = "tmp.js";
        FsoFramework.FileHandling.write( script, @"$(_script_path)/$(path)", true );

        yield ensure_connection();

        try
        {
            var result = yield _phonesim.run( path );
        }
        catch ( PhonesimError pe )
        {
            throw new RemotePhoneControlError.FAILED( @"Could not execute script on phonesim side: $(pe.message)" );
        }
        catch ( GLib.Error error )
        {
            throw new RemotePhoneControlError.FAILED( @"Could not excute script on phonesim side" );
        }
    }

    //
    // public API
    //

    public PhonesimRemotePhoneControl()
    {
        _script_path = GLib.DirUtils.make_tmp( "fsogsmd-integration-tests-XXXXXX" );
    }

    public async void initiate_call( string number, bool hide ) throws RemotePhoneControlError
    {
        string script = """tabCall.gbIncomingCall.leCaller.text = "%s"; tabCall.gbIncomingCall.pbIncomingCall.click();"""
            .printf( number );
        yield execute_script( script );
    }

    /*
     * FIXME id doesn't have to match as there are not exchanged between phonesim and
     * fsogsmd but if we keep everything in the right order and don't do crazy things
     * we can assume which id is used in phonesim for a new call easily.
     */
    public async void activate_incoming_call( int id ) throws RemotePhoneControlError
    {
        string script = """tabCall.twCallMgt.selectRow( %i ); tabCall.pbActive.click();""".printf( id );
        yield execute_script( script );
    }

    public override string repr()
    {
        return @"<>";
    }
}

public class FsoTest.TestGSM : FsoFramework.Test.TestCase
{
    private FreeSmartphone.GSM.Device gsm_device;
    private FreeSmartphone.GSM.Network gsm_network;
    private FreeSmartphone.GSM.SIM gsm_sim;
    private FreeSmartphone.GSM.Call gsm_call;
    private FreeSmartphone.GSM.PDP gsm_pdp;
    private FreeSmartphone.GSM.SMS gsm_sms;
    private FreeSmartphone.GSM.CB gsm_cb;
    private FreeSmartphone.GSM.VoiceMail gsm_voicemail;

    private struct Configuration
    {
        public string pin;
        public int default_timeout;
        public bool remote_enabled;
        public string remote_type;
        public string remote_number0;
    }

    private Configuration config;

    private IProcessGuard fsogsmd_process;
    private IProcessGuard phonesim_process;
    private IRemotePhoneControl remote_control;

    //
    // private
    //

    private bool start_daemon()
    {
        // FIXME check wether one of both processes is already running

        fsogsmd_process = new GProcessGuard();
        phonesim_process = new GProcessGuard();

        // FIXME prefix with directory where the phonesim configuration is stored
        if ( !phonesim_process.launch( new string[] { "phonesim", "-p", "3001", "-gui", "phonesim-default.xml" } ) )
            return false;

        Posix.sleep( 3 );

        if ( !fsogsmd_process.launch( new string[] { "fsogsmd", "--test" } ) )
            return false;

        Posix.sleep( 3 );

        return true;
    }

    private void stop_daemon()
    {
        GLib.Log.set_always_fatal( GLib.LogLevelFlags.LEVEL_CRITICAL );
        fsogsmd_process.stop();
        phonesim_process.stop();
    }

    private void validate_call( FreeSmartphone.GSM.CallDetail call, int expected_id,
        FreeSmartphone.GSM.CallStatus expected_status, string expected_number ) throws GLib.Error, AssertError
    {
        Assert.is_true( call.id == expected_id, "Expected call id $expected_id but got $(call.id)" );
        Assert.is_true( call.status == expected_status, @"Expected call status $expected_status but got $(call.status)" );
        if ( call.properties.size() > 0 )
        {
            var number = call.properties.lookup( "peer" );
            if ( number != null )
                Assert.is_true( number.get_string() == expected_number, @"Expected number $expected_number but got $(number.get_string())" );
            else Assert.fail( @"Missing property 'peer' in call status properties is not available" );
        }
        else Assert.fail( @"Missing property 'peer' in call status properties is not available" );
    }

    //
    // public
    //

    public TestGSM()
    {
        base("FreeSmartphone.GSM");

        config.default_timeout = theConfig.intValue( "default", "timeout", 60000 );
        config.pin = theConfig.stringValue( "default", "pin", "1234" );
        config.remote_enabled = theConfig.boolValue( "remote_control", "enabled", true );
        config.remote_type = theConfig.stringValue( "remote_control", "type", "phonesim" );
        config.remote_number0 = theConfig.stringValue( "remote_control", "number0", "+491234567890" );

        add_async_test( "ValidateInitialDeviceStatus",
                        cb => test_validate_initial_device_status( cb ),
                        res => test_validate_initial_device_status.end( res ), config.default_timeout );

        add_async_test( "ValidateInitialSimAuthStatus",
                        cb => test_validate_initial_sim_auth_status( cb ),
                        res => test_validate_initial_sim_auth_status.end( res ), config.default_timeout );

        add_async_test( "ValidateInitialNetworkStatus",
                        cb => test_validate_initial_network_status( cb ),
                        res => test_validate_initial_network_status.end( res ), config.default_timeout );

        add_async_test( "ValidateInitialDeviceFunctionality",
                        cb => test_validate_initial_device_functionality( cb ),
                        res => test_validate_initial_device_functionality.end( res ),
                        config.default_timeout );

        add_async_test( "SetFullDeviceFunctionality",
                        cb => test_set_full_device_functionality( cb ),
                        res => test_set_full_device_functionality.end( res ), config.default_timeout );

        if ( config.remote_enabled )
        {
            add_async_test( "IncomingCall",
                            cb => test_incoming_call( cb ),
                            res => test_incoming_call.end( res ), config.default_timeout );

            add_async_test( "AcceptIncomingCallAndReleaseLater",
                            cb => test_accept_incoming_call_and_release_later( cb ),
                            res => test_accept_incoming_call_and_release_later.end( res ),
                            config.default_timeout );

            add_async_test( "AcceptedOutgoingCall",
                            cb => test_accepted_outgoing_call( cb ),
                            res => test_accepted_outgoing_call.end( res ),
                            config.default_timeout );
        }

        add_async_test( "SetAirplaneDeviceFunctionality",
                        cb => test_set_airplane_device_functionality( cb ),
                        res => test_set_airplane_device_functionality.end( res ), config.default_timeout );

        // FIXME if we have different remote control types respect them here
        remote_control = new PhonesimRemotePhoneControl();

        start_daemon();

        try
        {
            gsm_device = Bus.get_proxy_sync<FreeSmartphone.GSM.Device>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_network = Bus.get_proxy_sync<FreeSmartphone.GSM.Network>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_sim = Bus.get_proxy_sync<FreeSmartphone.GSM.SIM>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_call = Bus.get_proxy_sync<FreeSmartphone.GSM.Call>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_pdp = Bus.get_proxy_sync<FreeSmartphone.GSM.PDP>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_sms = Bus.get_proxy_sync<FreeSmartphone.GSM.SMS>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_cb = Bus.get_proxy_sync<FreeSmartphone.GSM.CB>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );

            gsm_voicemail = Bus.get_proxy_sync<FreeSmartphone.GSM.VoiceMail>( BusType.SESSION, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.DO_NOT_AUTO_START );
        }
        catch ( GLib.Error err )
        {
            critical( @"Could not create proxy objects for GSM services: $(err.message)" );
        }
    }

    public void shutdown()
    {
        stop_daemon();
    }


    /**
     * Check the various status bits of the GSM service. All should be in a well definied
     * initial state. If state is not correct the cause is either wrong preconditions or
     * a real bug in the service implementation.
     */
    public async void test_validate_initial_device_status() throws GLib.Error, AssertError
    {
        var device_status = yield gsm_device.get_device_status();

        if ( device_status == FreeSmartphone.GSM.DeviceStatus.ALIVE_NO_SIM )
            Assert.fail( "No SIM is plugged into the device; can not continue" );
        else if ( device_status == FreeSmartphone.GSM.DeviceStatus.UNKNOWN )
            Assert.fail( "Can not continue as GSM device is in a unknown state" );
        else if ( device_status == FreeSmartphone.GSM.DeviceStatus.ALIVE_SIM_UNLOCKED ||
                  device_status == FreeSmartphone.GSM.DeviceStatus.ALIVE_REGISTERED )
            Assert.fail( "SIM card is already unlocked or modem registered to network; can't continue with testing" );
        else if ( device_status != FreeSmartphone.GSM.DeviceStatus.INITIALIZING &&
                  device_status != FreeSmartphone.GSM.DeviceStatus.ALIVE_SIM_LOCKED )
            Assert.fail( @"GSM device is in a unexpected state $device_status" );

        // Wait until modem leaves INITIALIZING state
        var retries = 5;
        while ( device_status == FreeSmartphone.GSM.DeviceStatus.INITIALIZING )
        {
            if ( retries == 0 )
                Assert.fail( @"Modem didn't leave INITIALIZING state in a reasonable time" );

            Timeout.add_seconds( 1, () => { test_validate_initial_device_status.callback(); return false; } );
            yield;

            device_status = yield gsm_device.get_device_status();
            retries--;
        }
    }

    public async void test_validate_initial_sim_auth_status() throws GLib.Error, AssertError
    {
        var sim_status = yield gsm_sim.get_auth_status();
        if ( sim_status != FreeSmartphone.GSM.SIMAuthStatus.PIN_REQUIRED &&
             sim_status != FreeSmartphone.GSM.SIMAuthStatus.PIN2_REQUIRED )
        {
            Assert.fail( @"SIM card has an unexpected state $sim_status" );
        }
    }

    public async void test_validate_initial_network_status() throws GLib.Error, AssertError
    {
        var network_status = yield gsm_network.get_status();
        // NOTE we're only checking for the following three entries as the spec defines
        // them as mandatory and all other are optional for the modem protocol
        // implementation.
        Assert.is_true( network_status.lookup( "mode" ) != null );
        Assert.is_true( network_status.lookup( "registration" ) != null );
        Assert.is_true( network_status.lookup( "act" ) != null );

        Assert.should_throw_async( cb => gsm_network.get_signal_strength( cb ),
                                   res => gsm_network.get_signal_strength.end( res ),
                                   FREESMARTPHONE_ERROR_DOMAIN );

        // FIXME This should be not available in this state too but is not; need to talk
        // to mickeyl about this.
        // Assert.should_throw_async( cb => gsm_network.list_providers( cb ),
        //                           res => gsm_network.list_providers.end( res ) );
    }

    public async void test_validate_initial_device_functionality() throws GLib.Error, AssertError
    {
        string level = "", pin = "";
        bool autoregister = false;

        yield gsm_device.get_functionality( out level, out autoregister, out pin );
        Assert.is_true( level == "minimal" || level == "airplane" );
        Assert.are_equal<bool>( autoregister, false );
        Assert.is_true( pin == "" || pin == null );
    }

    public async void test_set_full_device_functionality() throws GLib.Error, AssertError
    {
        string level = "", pin = "";
        bool autoregister = false;

        yield gsm_device.set_functionality( "full", true, config.pin );
        Timeout.add_seconds( 3, () => { test_set_full_device_functionality.callback(); return false; } );
        yield;

        var device_status = yield gsm_device.get_device_status();
        Assert.are_equal<FreeSmartphone.GSM.DeviceStatus>( device_status, FreeSmartphone.GSM.DeviceStatus.ALIVE_REGISTERED );

        var sim_auth_status = yield gsm_sim.get_auth_status();
        Assert.are_equal<FreeSmartphone.GSM.SIMAuthStatus>( sim_auth_status, FreeSmartphone.GSM.SIMAuthStatus.READY );

        yield gsm_device.get_functionality( out level, out autoregister, out pin );
        Assert.is_true( level == "full" );
        Assert.is_true( autoregister == true );
        Assert.is_true( pin == config.pin );
    }

    public async void test_validate_device_features() throws GLib.Error, AssertError
    {
        var features = yield gsm_device.get_features();
        Assert.is_true( features.lookup( "voice" ) != null, "Device does not mention voice feature" );
        Assert.is_true( features.lookup( "csd" ) != null, "Device does not mention csd feature" );
        Assert.is_true( features.lookup( "gsm" ) != null, "Device does not mention gsm feature" );
        Assert.is_true( features.lookup( "cdma" ) != null, "Device does not mention cdma feature" );
        Assert.is_true( features.lookup( "pdp" ) != null, "Device does not mention pdp feature" );
        Assert.is_true( features.lookup( "fax" ) != null, "Device does not mention fax feature" );
        Assert.is_true( features.lookup( "facilities" ) != null, "Device does not mention facilities feature" );
    }

    public async void test_set_airplane_device_functionality() throws GLib.Error, AssertError
    {
        string level = "", pin = "";
        bool autoregister = false;

        yield gsm_device.set_functionality( "airplane", false, "" );
        Timeout.add_seconds( 3, () => { test_set_airplane_device_functionality.callback(); return false; } );

        yield gsm_device.get_functionality( out level, out autoregister, out pin );
        Assert.is_true( level == "airplane" );
        // NOTE autoregister is only valid if level is "full"
        Assert.is_true( pin == config.pin );
    }

    public async void test_incoming_call() throws GLib.Error, AssertError
    {
        FreeSmartphone.GSM.CallDetail[] calls;

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );

        yield remote_control.initiate_call( config.remote_number0, false );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 1, @"Expected only one call but there are $(calls.length) calls" );
        validate_call( calls[0], 1, FreeSmartphone.GSM.CallStatus.INCOMING, config.remote_number0 );

        yield gsm_call.release( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );
    }

    public async void test_accept_incoming_call_and_release_later() throws GLib.Error, AssertError
    {
        FreeSmartphone.GSM.CallDetail[] calls;

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );

        yield remote_control.initiate_call( config.remote_number0, false );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 1 );
        validate_call( calls[0], 1, FreeSmartphone.GSM.CallStatus.INCOMING, config.remote_number0 );

        yield gsm_call.activate( 1 );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 1 );
        validate_call( calls[0], 1, FreeSmartphone.GSM.CallStatus.ACTIVE, config.remote_number0 );

        // let the call in active state for some seconds
        yield asyncWaitSeconds( 2 );
        yield gsm_call.release( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );
    }

    public async void test_accepted_outgoing_call() throws GLib.Error, AssertError
    {
        FreeSmartphone.GSM.CallDetail[] calls;

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );

        var id = yield gsm_call.initiate( config.remote_number0, "voice" );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 1 );
        validate_call( calls[0], 1, FreeSmartphone.GSM.CallStatus.OUTGOING, config.remote_number0 );

        yield remote_control.activate_incoming_call( 0 );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 1 );
        validate_call( calls[0], 1, FreeSmartphone.GSM.CallStatus.ACTIVE, config.remote_number0 );

        yield gsm_call.release( 1 );
        yield asyncWaitSeconds( 1 );

        calls = yield gsm_call.list_calls();
        Assert.is_true( calls.length == 0 );
    }
}

FsoTest.TestGSM gsm_suite = null;

public static void sighandler( int signum )
{
    Posix.signal( signum, null ); // restore original sighandler
    gsm_suite.shutdown();
    FsoFramework.theLogger.info( "received signal -%d, exiting.".printf( signum ) );
}

public static int main( string[] args )
{
    GLib.Test.init( ref args );

    Posix.signal( Posix.SIGINT, sighandler );
    Posix.signal( Posix.SIGTERM, sighandler );
    Posix.signal( Posix.SIGBUS, sighandler );
    Posix.signal( Posix.SIGSEGV, sighandler );
    Posix.signal( Posix.SIGABRT, sighandler );
    Posix.signal( Posix.SIGTRAP, sighandler );

    TestSuite root = TestSuite.get_root();
    gsm_suite = new FsoTest.TestGSM();
    root.add_suite( gsm_suite.get_suite() );

    GLib.Test.run();

    gsm_suite.shutdown();

    return 0;
}

// vim:ts=4:sw=4:expandtab
