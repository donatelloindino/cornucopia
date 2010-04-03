/*
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

using GLib;
using Gee;
using FsoGsm;

/**
 * @class QualcommPalm.Modem
 *
 * This modem plugin supports the Qualcomm MSM chipset used on Palm Pre (Plus).
 *
 * The modem uses a binary protocol which has been implemented in libmsmcomm.
 **/
class QualcommPalm.Modem : FsoGsm.AbstractModem
{
    private const string AT_CHANNEL_NAME = "data";
    private const string MSM_CHANNEL_NAME = "main";

    public override string repr()
    {
        return "<>";
    }

    protected override void createChannels()
    {
#if 0
        // create AT channel for data use
        var datatransport = FsoFramework.Transport.create( data_transport, data_port, data_speed );
        var parser = new FsoGsm.StateBasedAtParser();
        new FsoGsm.AtChannel( AT_CHANNEL_NAME, datatransport, parser );
#endif
        // create MAIN channel
        var maintransport = FsoFramework.Transport.create( modem_transport, modem_port, modem_speed );
        new MsmChannel( MSM_CHANNEL_NAME, maintransport );
    }

    protected override FsoGsm.Channel channelForCommand( FsoGsm.AtCommand command, string query )
    {
        // nothing to do here as qualcomm_palm only has one AT channel
        return channels[ AT_CHANNEL_NAME ];
    }

    protected override void registerCustomMediators( HashMap<Type,Type> mediators )
    {
        registerMsmMediators( mediators );
    }
}

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    FsoFramework.theLogger.debug( "qualcomm_palm fso_factory_function" );
    return "fsogsm.modem_qualcomm_palm";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    // do not remove this function
}

/**
 * This function gets called on plugin load time.
 * @return false, if the plugin operating conditions are present.
 * @note Some versions of glib contain a bug that leads to a SIGSEGV
 * in g_module_open, if you return true here.
 **/
/*public static bool g_module_check_init( void* m )
{
    var ok = FsoFramework.FileHandling.isPresent( Kernel26.SYS_CLASS_LEDS );
    return (!ok);
}
*/
