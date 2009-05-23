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

namespace Alsa
{

/**
 * Alsa Audio Player
 **/
class AudioPlayer : FreeSmartphone.Device.Audio, FsoFramework.AbstractObject
{
    private FsoFramework.Subsystem subsystem;
    private Canberra.Context context;

    [Compact]
    public class Sound
    {
        public Sound( string name, int loop, int length, int cid )
        {
            this.name = name;
            this.loop = loop;
            this.length = length;
            this.cid = cid;
            message( "%s %d create", name, cid );
        }
        ~Sound()
        {
            message( "%s %d destroy", name, cid );
        }
        public string name;
        public int loop;
        public int length;
        public int cid;

    }

    private HashTable<string,Sound> sounds;

    public AudioPlayer( FsoFramework.Subsystem subsystem )
    {
        this.subsystem = subsystem;

        subsystem.registerServiceName( FsoFramework.Device.ServiceDBusName );
        subsystem.registerServiceObject( FsoFramework.Device.ServiceDBusName,
                                         FsoFramework.Device.AudioServicePath,
                                         this );

        sounds = new HashTable<string,Sound>( str_hash, str_equal );
        Canberra.Context.create( &context );

        logger.info( "created." );
    }

    public override string repr()
    {
        return "<ALSA>";
    }

    public void onSoundFinished( Canberra.Context context, uint32 id, Canberra.Error code )
    {
        logger.debug( "sound finished with name %s, code %s".printf( (string)id, Canberra.strerror( code ) ) );
        weak Sound sound = sounds.lookup( (string)id );
        assert ( sound != null );
        //FIXME send stopped signal
        sounds.remove( (string)id );
    }

    //
    // DBUS API
    //

    public string[] get_available_scenarios() throws DBus.Error
    {
        return {};
    }

    public HashTable<string,Value?> get_info() throws DBus.Error
    {
        return new HashTable<string,Value?>( str_hash, str_equal );
    }

    public string get_scenario() throws DBus.Error
    {
        return "unknown";
    }

    public string[] get_supported_formats() throws DBus.Error
    {
        return { "*.wav" };
    }

    public void play_sound( string name, int loop, int length ) throws FreeSmartphone.Device.AudioError, DBus.Error
    {
        weak Sound sound = sounds.lookup( name );
        if ( sound != null )
            throw new FreeSmartphone.Device.AudioError.ALREADY_PLAYING( "%s is already playing".printf( name ) );

        Canberra.Proplist p = null;
        Canberra.Proplist.create( &p );
        p.sets( Canberra.PROP_MEDIA_FILENAME, name );

        Canberra.Error res = context.play_full( (uint32)name, p, onSoundFinished );

        if ( res != Canberra.SUCCESS )
        {
            throw new FreeSmartphone.Device.AudioError.PLAYER_ERROR( "Can't play song %s: %s".printf( name, Canberra.strerror( res ) ) );
        }

        sounds.insert( name, new Sound( name, loop, length, (int)name ) );
    }

    public string pull_scenario() throws DBus.Error
    {
        return "unknown";
    }

    public void push_scenario( string scenario ) throws DBus.Error
    {
    }

    public void set_scenario( string scenario ) throws DBus.Error
    {
    }

    public void stop_all_sounds() throws DBus.Error
    {
        foreach ( var name in sounds.get_keys() )
            stop_sound( name );
    }

    public void stop_sound( string name ) throws DBus.Error
    {
        weak Sound sound = sounds.lookup( name );
        if ( sound == null )
            return;

        Canberra.Error res = context.cancel( sound.cid );
        logger.debug( "cancelling %s (%d) result: %s".printf( sound.name, sound.cid, Canberra.strerror( res ) ) );
    }

}

} /* namespace */

internal Alsa.AudioPlayer instance;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    instance = new Alsa.AudioPlayer( subsystem );

    return "fsodevice.alsa_audio";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    debug( "input fso_register_function()" );
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