/*
 * (C) 2011 Simon Busch <morphis@gravedo.de>
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

public class FsoTest.TestGSM : FsoTest.Fixture
{
    private FreeSmartphone.Usage usage;
    private FreeSmartphone.GSM.Device gsm_device;
    private FreeSmartphone.GSM.Network gsm_network;
    private FreeSmartphone.GSM.SIM gsm_sim;
    private FreeSmartphone.GSM.Call gsm_call;
    private FreeSmartphone.GSM.PDP gsm_pdp;
    private FreeSmartphone.GSM.SMS gsm_sms;
    private FreeSmartphone.GSM.CB gsm_cb;
    private FreeSmartphone.GSM.VoiceMail gsm_voicemail;

    public TestGSM()
    {
        name = "GSM";
    }

    public override async void setup()
    {
        try
        {
            usage = Bus.get_proxy_sync<FreeSmartphone.Usage>( BusType.SYSTEM, FsoFramework.Usage.ServiceDBusName,
                FsoFramework.Usage.ServicePathPrefix );

            gsm_device = Bus.get_proxy_sync<FreeSmartphone.GSM.Device>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_network = Bus.get_proxy_sync<FreeSmartphone.GSM.Network>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_sim = Bus.get_proxy_sync<FreeSmartphone.GSM.SIM>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_call = Bus.get_proxy_sync<FreeSmartphone.GSM.Call>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_pdp = Bus.get_proxy_sync<FreeSmartphone.GSM.PDP>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_sms = Bus.get_proxy_sync<FreeSmartphone.GSM.SMS>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_cb = Bus.get_proxy_sync<FreeSmartphone.GSM.CB>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );

            gsm_voicemail = Bus.get_proxy_sync<FreeSmartphone.GSM.VoiceMail>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                FsoFramework.GSM.DeviceServicePath );
        }
        catch ( GLib.Error err )
        {
            critical( @"Could not create proxy objects for GSM services: $(err.message)" );
        }
    }

    public override bool run( TestManager test_manager )
    {
        bool result = false;

        result = test_manager.run_test_method( "/org/freesmartphone/GSM/RequestResource", () => {
            wait_for_async( 200, cb => test_request_gsm_resource( cb ),
                res => test_request_gsm_resource.end( res ) );
        } );
        return_val_if_fail( result, false );

        result = test_manager.run_test_method( "/org/freesmartphone/GSM/Releaseresource", () => {
            wait_for_async( 200, cb => test_release_gsm_resource( cb ),
                res => test_release_gsm_resource.end( res ) );
        } );
        return_val_if_fail( result, false );

        return true;
    }

    /**
     * Test GSM resource registration as very often the modem is initialized while the
     * user requests the resource. If the resource is still accessible after the request
     * the test is successfull.
     */
    public async void test_request_gsm_resource() throws GLib.Error, AssertError
    {
        string[] resources;

        resources = yield usage.list_resources();
        Assert.is_true( "GSM" in resources );

        yield usage.request_resource( "GSM" );

        resources = yield usage.list_resources();
        Assert.is_true( "GSM" in resources );
    }

    public async void test_release_gsm_resource() throws GLib.Error, AssertError
    {
        yield usage.release_resource( "GSM" );
    }

    public override void teardown()
    {
    }
}



// vim:ts=4:sw=4:expandtab
