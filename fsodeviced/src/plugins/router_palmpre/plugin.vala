/**
 * Copyright (C) 2010 Simon Busch <morphis@gravedo.de>
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

const string FSO_PALMPRE_AUDIO_SCRUN_PATH = "/sys/devices/platform/twl4030_audio/scrun";
const string FSO_PALMPRE_AUDIO_SCINIT_PATH = "/sys/devices/platform/twl4030_audio/scinit";

namespace Router
{

private class KernelScriptInterface
{
    public static void loadAndStoreScriptFromFile(string filename)
    {
        if (FsoFramework.FileHandling.isPresent(filename))
        {
            string script = FsoFramework.FileHandling.read(filename);
            FsoFramework.FileHandling.write(FSO_PALMPRE_AUDIO_SCINIT_PATH, script);
        }
    }

    public static void runScript(string script_name)
    {
        FsoFramework.theLogger.debug( @"executing audio script '$(script_name)'" );
        FsoFramework.FileHandling.write(FSO_PALMPRE_AUDIO_SCRUN_PATH, script_name);
    }
    
    public static void runScripts(string[] scripts)
    {
        foreach ( var script in scripts )
        {
            runScript( script );
        }
    }
}

private enum AudioStateType
{
    MEDIA_BACKSPEAKER,
    MEDIA_A2DP,
    MEDIA_FRONTSPEAKER,
    MEDIA_HEADSET,
    MEDIA_HEADSET_MIC,
    MEDIA_WIRELESS,
    PHONE_BACKSPEAKER,
    PHONE_BLUETOOTH,
    PHONE_FRONTSPEAKER,
    PHONE_HEADSET,
    PHONE_HEADSET_MIC,
    PHONE_TTY_FULL,
    PHONE_TTY_HCO,
    PHONE_TTY_VCO,
    VOICE_DIALING_BACKSPEAKER,
    VOICE_DIALING_BLUETOOTH_SCO,
    VOICE_DIALING_FRONTSPEAKER,
    VOICE_DIALING_HEADSET_MIC,
    VOICE_DIALING_HEADSET,
}

private string audioStateTypeToString( AudioStateType state )
{
    string result = "<unknown>";
    
    switch ( state )
    {
        case AudioStateType.MEDIA_BACKSPEAKER:
            result = "MEDIA_BACKSPEAKER";
            break;
        case AudioStateType.MEDIA_A2DP:
            result = "MEDIA_A2DP";
            break;
        case AudioStateType.MEDIA_FRONTSPEAKER:
            result = "MEDIA_FRONTSPEAKER";
            break;
        case AudioStateType.MEDIA_HEADSET:
            result = "MEDIA_HEADSET";
            break;
        case AudioStateType.MEDIA_HEADSET_MIC:
            result = "MEDIA_HEADSET_MIC";
            break;
        case AudioStateType.MEDIA_WIRELESS:
            result = "MEDIA_WIRELESS";
            break;
        case AudioStateType.PHONE_BACKSPEAKER:
            result = "PHONE_BACKSPEAKER";
            break;
        case AudioStateType.PHONE_BLUETOOTH:
            result = "PHONE_BLUETOOTH";
            break;
        case AudioStateType.PHONE_FRONTSPEAKER:
            result = "PHONE_FRONTSPEAKER";
            break;
        case AudioStateType.PHONE_HEADSET:
            result = "PHONE_HEADSET";
            break;
        case AudioStateType.PHONE_HEADSET_MIC:
            result = "PHONE_HEADSET_MIC";
            break;
        case AudioStateType.PHONE_TTY_FULL:
            result = "PHONE_TTY_FULL";
            break;
        case AudioStateType.PHONE_TTY_HCO:
            result = "PHONE_TTY_HCO";
            break;
        case AudioStateType.PHONE_TTY_VCO:
            result = "PHONE_TTY_VCO";
            break;
        case AudioStateType.VOICE_DIALING_BACKSPEAKER:
            result = "VOICE_DIALING_BACKSPEAKER";
            break;
        case AudioStateType.VOICE_DIALING_BLUETOOTH_SCO:
            result = "VOICE_DIALING_BLUETOOTH_SCO";
            break;
        case AudioStateType.VOICE_DIALING_FRONTSPEAKER:
            result = "VOICE_DIALING_FRONTSPEAKER";
            break;
        case AudioStateType.VOICE_DIALING_HEADSET_MIC:
            result = "VOICE_DIALING_HEADSET_MIC";
            break;
        case AudioStateType.VOICE_DIALING_HEADSET:
            result = "VOICE_DIALING_HEADSET";
            break;
    }
    
    return result;
}

private enum AudioEventType
{
    NONE,
    CALL_STARTED,
    CALL_ENDED,
    HEADSET_IN,
    HEADSET_OUT,
    SWITCH_TO_BACK_SPEAKER,
    SWITCH_TO_FRONT_SPEAKER,
    VOIP_STARTED,
    VOIP_ENDED,
}

private AudioEventType stringToAudioEventType( string str )
{
    AudioEventType event = AudioEventType.NONE;
    
    switch ( str )
    {
        case "CALL_STARTED":
            event = AudioEventType.CALL_STARTED;
            break;
        case "CALL_ENDED":
            event = AudioEventType.CALL_ENDED;
            break;
        case "HEADSET_IN":
            event = AudioEventType.HEADSET_IN;
            break;
        case "HEADSET_OUT":
            event = AudioEventType.HEADSET_OUT;
            break;
        case "SWITCH_TO_BACK_SPEAKER":
            event = AudioEventType.SWITCH_TO_BACK_SPEAKER;
            break;
        case "SWITCH_TO_FRONT_SPEAKER":
            event = AudioEventType.SWITCH_TO_FRONT_SPEAKER;
            break;
        case "VOIP_STARTED":
            event = AudioEventType.VOIP_STARTED;
            break;
        case "VOIP_ENDED":
            event = AudioEventType.VOIP_ENDED;
            break;
    }
    
    return event;
}

private string audioEventTypeToString( AudioEventType event )
{
    string result = "<unknown>";
    switch ( event )
    {
        case AudioEventType.CALL_STARTED:
            result = "CALL_STARTED";
            break;
        case AudioEventType.CALL_ENDED:
            result = "CALL_ENDED";
            break;
        case AudioEventType.HEADSET_IN:
            result = "HEADSET_IN";
            break;
        case AudioEventType.HEADSET_OUT:
            result = "HEADSET_OUT";
            break;
        case AudioEventType.SWITCH_TO_BACK_SPEAKER:
            result = "SWITCH_TO_BACK_SPEAKER";
            break;
        case AudioEventType.SWITCH_TO_FRONT_SPEAKER:
            result = "SWITCH_TO_FRONT_SPEAKER";
            break;
        case AudioEventType.VOIP_STARTED:
            result = "VOIP_STARTED";
            break;
        case AudioEventType.VOIP_ENDED:
            result = "VOIP_ENDED";
            break;
    }
    return result;
}

private class AudioTransition : GLib.Object
{
    public AudioStateType next_state 
    { 
        get; private set;
    }
    
    public AudioEventType event 
    { 
        get; private set;
    }
    
    public AudioTransition( AudioEventType event, AudioStateType next_state )
    {
        this.event = event;
        this.next_state = next_state;
    }
}

/**
 * palmpre Audio Router
 **/
class PalmPre : FsoDevice.BaseAudioRouter
{
    private const string MODULE_NAME = "fsodevice.router_palmpre";
    private Gee.HashMap<AudioStateType,Gee.ArrayList<AudioTransition>> transitions;
    private AudioStateType current_state;
    private string[] available_events = {};
    
    construct
    {
        current_state = AudioStateType.MEDIA_BACKSPEAKER;
        
        /*
         * Here we add all currently available state transitions
         */
        
        transitions = new Gee.HashMap<AudioStateType,Gee.ArrayList<AudioTransition>>();
        
        transitions[AudioStateType.MEDIA_BACKSPEAKER] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.MEDIA_BACKSPEAKER].add(new AudioTransition( AudioEventType.HEADSET_IN, AudioStateType.MEDIA_HEADSET ) );
        transitions[AudioStateType.MEDIA_BACKSPEAKER].add(new AudioTransition( AudioEventType.CALL_STARTED, AudioStateType.PHONE_BACKSPEAKER ) ) ;
        transitions[AudioStateType.MEDIA_BACKSPEAKER].add(new AudioTransition( AudioEventType.SWITCH_TO_FRONT_SPEAKER, AudioStateType.MEDIA_FRONTSPEAKER ) );
        
        transitions[AudioStateType.MEDIA_FRONTSPEAKER] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.MEDIA_FRONTSPEAKER].add(new AudioTransition( AudioEventType.SWITCH_TO_BACK_SPEAKER, AudioStateType.MEDIA_BACKSPEAKER ) );
        transitions[AudioStateType.MEDIA_FRONTSPEAKER].add(new AudioTransition( AudioEventType.HEADSET_IN, AudioStateType.MEDIA_HEADSET ) );
        transitions[AudioStateType.MEDIA_FRONTSPEAKER].add(new AudioTransition( AudioEventType.CALL_STARTED, AudioStateType.PHONE_FRONTSPEAKER ) );
        
        transitions[AudioStateType.MEDIA_HEADSET] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.MEDIA_HEADSET].add(new AudioTransition( AudioEventType.HEADSET_OUT, AudioStateType.MEDIA_BACKSPEAKER ) );
        transitions[AudioStateType.MEDIA_HEADSET].add(new AudioTransition( AudioEventType.CALL_STARTED, AudioStateType.PHONE_HEADSET ) );
        
        transitions[AudioStateType.PHONE_BACKSPEAKER] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.PHONE_BACKSPEAKER].add(new AudioTransition( AudioEventType.HEADSET_IN, AudioStateType.PHONE_HEADSET ) );
        transitions[AudioStateType.PHONE_BACKSPEAKER].add(new AudioTransition( AudioEventType.CALL_ENDED, AudioStateType.MEDIA_BACKSPEAKER ) );
        transitions[AudioStateType.PHONE_BACKSPEAKER].add(new AudioTransition( AudioEventType.SWITCH_TO_FRONT_SPEAKER, AudioStateType.PHONE_FRONTSPEAKER ) );
        
        transitions[AudioStateType.PHONE_FRONTSPEAKER] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.PHONE_FRONTSPEAKER].add(new AudioTransition( AudioEventType.HEADSET_IN, AudioStateType.PHONE_HEADSET ) );
        transitions[AudioStateType.PHONE_FRONTSPEAKER].add(new AudioTransition( AudioEventType.CALL_ENDED, AudioStateType.MEDIA_FRONTSPEAKER ) );
        transitions[AudioStateType.PHONE_FRONTSPEAKER].add(new AudioTransition( AudioEventType.SWITCH_TO_BACK_SPEAKER, AudioStateType.PHONE_BACKSPEAKER ) );
        
        transitions[AudioStateType.PHONE_HEADSET] = new Gee.ArrayList<AudioTransition>();
        transitions[AudioStateType.PHONE_HEADSET].add(new AudioTransition( AudioEventType.HEADSET_OUT, AudioStateType.PHONE_BACKSPEAKER ) );
        transitions[AudioStateType.PHONE_HEADSET].add(new AudioTransition( AudioEventType.CALL_ENDED, AudioStateType.MEDIA_HEADSET ) );
        transitions[AudioStateType.PHONE_HEADSET].add(new AudioTransition( AudioEventType.SWITCH_TO_BACK_SPEAKER, AudioStateType.PHONE_BACKSPEAKER ) );
        transitions[AudioStateType.PHONE_HEADSET].add(new AudioTransition( AudioEventType.SWITCH_TO_FRONT_SPEAKER, AudioStateType.PHONE_FRONTSPEAKER ) );
        
        /*
         * All available events
         */
        
        available_events += audioEventTypeToString(AudioEventType.CALL_STARTED);
        available_events += audioEventTypeToString(AudioEventType.CALL_ENDED);
        available_events += audioEventTypeToString(AudioEventType.HEADSET_IN);
        available_events += audioEventTypeToString(AudioEventType.HEADSET_OUT);
        available_events += audioEventTypeToString(AudioEventType.SWITCH_TO_BACK_SPEAKER);
        available_events += audioEventTypeToString(AudioEventType.SWITCH_TO_FRONT_SPEAKER);
        available_events += audioEventTypeToString(AudioEventType.VOIP_STARTED);
        available_events += audioEventTypeToString(AudioEventType.VOIP_ENDED);
    }
    
    private void handleEvent( AudioEventType event )
    {   
        foreach ( var transition in transitions[current_state] )
        {
            if ( transition.event == event ) 
            {
                FsoFramework.theLogger.debug( @"Event '$(audioEventTypeToString(event))' is known by the current state '$(audioStateTypeToString(current_state))'" );
                releaseState( current_state );
                initState ( transition.next_state );
                FsoFramework.theLogger.debug( @"Switched to '$(audioStateTypeToString(current_state))' state" );
                current_state = transition.next_state;
                break;
            }
            
            if ( transition.event == AudioEventType.CALL_STARTED )
            {
                KernelScriptInterface.runScript( "call_started" );
            }
            else if ( transition.event == AudioEventType.CALL_ENDED ) 
            {
                KernelScriptInterface.runScript( "call_ended" );
            }
        }
    }
    
    private void initState( AudioStateType state )
    {   
        string[] scripts = { };
        
        FsoFramework.theLogger.debug(@"Init '$(audioStateTypeToString(state))' state");
        
        switch ( state )
        {
            case AudioStateType.MEDIA_BACKSPEAKER:
                scripts += "media_back_speaker";
                break;
            case AudioStateType.MEDIA_FRONTSPEAKER:
                scripts += "media_front_speaker";
                break;
            case AudioStateType.MEDIA_HEADSET:
                scripts += "media_headset";
                break;
            case AudioStateType.PHONE_BACKSPEAKER:
                scripts += "phone_back_speaker";
                break;
            case AudioStateType.PHONE_FRONTSPEAKER:
                scripts += "phone_front_speaker";
                break;
            case AudioStateType.PHONE_HEADSET:
                scripts += "phone_headset";
                break;
        }
        
        KernelScriptInterface.runScripts(scripts);
    }
    
    private void releaseState( AudioStateType state )
    {   
        string[] scripts = { };
        
        FsoFramework.theLogger.debug(@"Release '$(audioStateTypeToString(state))' state");
        
        switch ( state )
        {
            default:
                break;
        }
        
        KernelScriptInterface.runScripts(scripts);
    }
    
    public override void setScenario( string scenario )
    {
        FsoFramework.theLogger.debug("got a $(scenario) audio event");
        // For now we treat the scenario give as event. API need to be 
        // reworked for a audio state machine ...
        handleEvent( stringToAudioEventType( scenario.up() ) );
    }
    
    public override bool isScenarioAvailable( string scenario )
    {
        return (scenario in available_events);
    }

    public override override string[] availableScenarios()
    {
        return available_events;
    }
    
    /*
     * NOTE: The following methods are not used by this plugin as we 
     *       don't implement audio routing in the way the other plugins
     *       does.
     */

    public override string currentScenario()
    {
        return "";
    }

    public override string pullScenario() throws FreeSmartphone.Device.AudioError
    {
        return "";
    }

    public override void pushScenario( string scenario )
    {
    }

    public override void saveScenario( string scenario )
    {
    }

    public override uint8 currentVolume() throws FreeSmartphone.Error
    {
        return 0;
    }

    public override void setVolume( uint8 volume ) throws FreeSmartphone.Error
    {
    }
}

} /* namespace Router */

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    // instances will be created on demand by fsodevice.audio
    return "fsodevice.router_palmpre";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsodevice.router_palmpre fso_register_function()" );
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
