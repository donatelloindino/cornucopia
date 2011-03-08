/*
 * Copyright (C) 2011 Simon Busch <morphis@gravedo.de>
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

namespace FsoAudio
{
    public static const string ROUTER_ALSA_MODULE_NAME = "fsoaudio.router_alsa";
}

public class Router.Alsa : FsoAudio.AbstractRouter
{
    construct
    {
        normal_supported_devices = new FreeSmartphone.Audio.Device[] {
            FreeSmartphone.Audio.Device.BACKSPEAKER,
            FreeSmartphone.Audio.Device.FRONTSPEAKER,
            FreeSmartphone.Audio.Device.HEADSET
        };

        call_supported_devices = new FreeSmartphone.Audio.Device[] {
            FreeSmartphone.Audio.Device.BACKSPEAKER,
            FreeSmartphone.Audio.Device.FRONTSPEAKER,
            FreeSmartphone.Audio.Device.HEADSET
        };

        logger.info( @"Created and configured." );
    }

    public override string repr()
    {
        return "<>";
    }

    public override void set_mode( FreeSmartphone.Audio.Mode mode )
    {
        if ( mode == current_mode )
        {
            return;
        }

        var previous_mode = current_mode;
        base.set_mode( mode );
    }

    public override void set_device( FreeSmartphone.Audio.Device device, bool expose = true )
    {
        base.set_device( device, expose );
    }

    public override void set_volume( FreeSmartphone.Audio.Control control, uint volume )
    {
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
    return FsoAudio.ROUTER_ALSA_MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsoaudio.manager fso_register_function" );
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
