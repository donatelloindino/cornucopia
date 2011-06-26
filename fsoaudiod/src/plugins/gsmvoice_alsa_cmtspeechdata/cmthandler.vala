/*
 * Copyright (C) 2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2011 Denis 'GNUtoo' Carikli <GNUtoo@no-log.org>
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
 * @class CmtHandler
 *
 * Handles Audio via libcmtspeechdata
 **/
public class CmtHandler : FsoFramework.AbstractObject
{
    private CmtSpeech.Connection connection;
    private IOChannel channel;
    private FsoAudio.PcmDevice pcmout;
    private FsoAudio.PcmDevice pcmin;
    private bool status;
    private const int FCOUNT = 160;

    /* playback Thread */
    private unowned Thread<void *> playbackThread = null;
    private bool runPlaybackThread = false;
    private uint8 from_modem_to_writei[960]; //3 buffers of 160 frames: 3*(160 * 2)
    private Mutex playbackMutex = new Mutex();
    private long writeiWriteptr = 0;
    private long writeiReadptr = 0;

    /* record Thread */
    private unowned Thread<void *> recordThread = null;
    private bool runRecordThread = false;
    private uint8 from_readi_to_modem[960]; //3 buffers of 160 frames: 3*(160 * 2)
    private Mutex recordMutex = new Mutex();
    private long readiWriteptr = 0;
    private long readiReadptr = 0;

    //
    // Constructor
    //
    public CmtHandler()
    {
        status = false;

        assert( logger.debug( "Initializing cmtspeech" ) );
        CmtSpeech.init();

        assert( logger.debug( "Setting up traces" ) );
        CmtSpeech.trace_toggle( CmtSpeech.TraceType.STATE_CHANGE, true );
        CmtSpeech.trace_toggle( CmtSpeech.TraceType.IO, true );
        CmtSpeech.trace_toggle( CmtSpeech.TraceType.DEBUG, true );

        assert( logger.debug( "Instanciating connection" ) );
        connection = new CmtSpeech.Connection();
        if ( connection == null )
        {
            logger.error( "Can't instanciate connection" );
            return;
        }

        var fd = connection.descriptor();

        if ( fd == -1 )
        {
            logger.error( "Cmtspeech file descriptor invalid" );
        }

        assert( logger.debug( "Hooking up fd with main loop" ) );
        channel = new IOChannel.unix_new( fd );
        channel.add_watch( IOCondition.IN | IOCondition.HUP, onInputFromChannel );

        logger.info( "Created" );
    }

    //
    // Private API
    //

    private int checkReadiPosition(out int readptr,out int writeptr)
    {
        if ( readptr - writeptr > (FCOUNT * 2) )
        {
            //buffer underrun
            recordMutex.lock();
            if ( readptr + (FCOUNT * 2) > 480 )
                writeptr = readptr + ( FCOUNT * 2) - 480;
            else
                writeptr = readptr + (FCOUNT *2 );
            recordMutex.unlock();
            return -Posix.EPIPE;
        }
        return 0;
    }



    private int checkWriteiPosition(out int readptr,out int writeptr){
        if ( readptr - writeptr > (FCOUNT * 2) )
        {
            //buffer underrun
            playbackMutex.lock();
            if ( readptr + (FCOUNT * 2) > 480 )
                writeptr = readptr + ( FCOUNT * 2) - 480;
            else
                writeptr = readptr + (FCOUNT *2 );
            playbackMutex.unlock();
            return -Posix.EPIPE;
        }
        // else if(writeptr + FCOUNT > readptr)
        // {
        //     //
        //     playbackMutex.Lock();
        //     if (writeptr + FCOUNT > 480)
        //         readptr = writeptr + FCOUNT - 480;
        //     else
        //         readptr = writeptr + FCOUNT;
        //     playbackMutex.unlock();
        //     return -Posix.EIO;
        // }
        return 0;
    }

    private void updatePtr(out long ptr, Alsa.PcmSignedFrames  frames){
        long num = (long) frames;

        if ( ( ptr + num ) > 480 )
             ptr += ( ptr + num ) - 480;
        else
            ptr += num;
    }

    private void * playbackThreadFunc()
    {
        Alsa.PcmSignedFrames frames;
        int ret;

        while ( runPlaybackThread )
        {
            ret = checkWriteiPosition( out writeiReadptr ,out writeiWriteptr);
            if (ret == -Posix.EPIPE)
            {
                stderr.printf("buffer underruns\n");
                try
                {
                    pcmout.prepare();
                }
                catch ( FsoAudio.SoundError e )
                {
                    //I don't know what to do at this point,
                    //sound won't work anymore.
                    //hangup?
                    logger.error( "Error in snd_pcm_prepare after a buffer underrun!!!!" );
                    logger.error( @"Error: $(e.message)" );
                }
            }
            else
            {
                try
                {
                       frames = pcmout.writei(
                           (uint8[])((int)from_modem_to_writei + (int)writeiReadptr) ,FCOUNT );
                       frames = frames * 2;
                       if ( frames == -Posix.EPIPE )
                       {
                              //pcmout.recover(-Posix.EPIPE,0);
                           //frames = FCOUNT;
                           //updatePtr(out writeiReadptr, FCOUNT);
                           pcmout.prepare();
                       }
                       else
                       {
                           updatePtr(out writeiReadptr, frames);
                       }
                }
                catch ( FsoAudio.SoundError e )
                {
                    logger.error( @"Error: $(e.message)" );
                }

            }
        }
        return null;
    }


    private void * recordThreadFunc()
    {
        Alsa.PcmSignedFrames frames;
        int ret;

        while ( runRecordThread )
        {
            ret = checkReadiPosition( out readiReadptr ,out readiWriteptr);
            if (ret == -Posix.EPIPE)
            {
                stderr.printf("buffer overruns\n");
                try
                {
                    pcmin.prepare();
                }
                catch ( FsoAudio.SoundError e )
                {
                    //I don't know what to do at this point,
                    //sound won't work anymore.
                    //hangup?
                    logger.error( "Error in snd_pcm_prepare after a buffer underrun!!!!" );
                    logger.error( @"Error: $(e.message)" );
                }
            }
            else
            {
                try
                {
                       frames = pcmin.readi(
                           (uint8[])((int)from_readi_to_modem + (int)readiWriteptr) ,FCOUNT );
                       frames = frames * 2;
                       if ( frames == -Posix.EPIPE )
                       {
                              //pcmin.recover(-Posix.EPIPE,0);
                           //frames = FCOUNT;
                           //updatePtr(out readiWriteptr, FCOUNT);
                           pcmin.prepare();
                       }
                       else
                       {
                           updatePtr(out readiWriteptr, frames);
                       }
                }
                catch ( FsoAudio.SoundError e )
                {
                    logger.error( @"Error: $(e.message)" );
                }

            }
        }
        return null;
    }


    // private Alsa.PcmSignedFrames handleAlsaSink( CmtSpeech.FrameBuffer dlbuf )
    // {
    //     try
    //     {
    //         return pcmout.writei( (uint8[])dlbuf.payload, dlbuf.pcount / 2 );
    //     }
    //     catch ( FsoAudio.SoundError e )
    //     {
    //         logger.error( @"Error: $(e.message)" );
    //     }
    //     return 0;
    // }

    // private void handleAlsaSrc( CmtSpeech.FrameBuffer ulbuf )
    // {
    //     Alsa.PcmSignedFrames frames;
    //     try
    //     {
    //         /* 160 S16_LE frames == 320 Bytes */
    //         frames = pcmin.readi( (uint8[]) ulbuf.payload , FCOUNT );
    //         if (frames == -Posix.EPIPE)
    //         {
    //             logger.debug("WARNING: buffer overrun occured with readi\n");
    //             pcmin.recover(-Posix.EPIPE,0);
    //            return;
    //         }
    //     }
    //     catch ( FsoAudio.SoundError e )
    //     {
    //         logger.error( @"Error: $(e.message)" );
    //     }
    // }

    private void alsaSinkSetup()
    {
        int channels = 1;
        int rate = 8000;
        Alsa.PcmFormat format = Alsa.PcmFormat.S16_LE;
        Alsa.PcmAccess access = Alsa.PcmAccess.RW_INTERLEAVED;

        pcmout = new FsoAudio.PcmDevice();
        assert( logger.debug( @"Setup alsa sink for modem audio" ) );
        try
        {
            pcmout.open( "plug:dmix" );
            pcmout.setFormat( access, format, rate, channels );
        }
        catch ( Error e )
        {
            logger.error( @"Error: $(e.message)" );
        }

        /* start the playback thread now
         */
        if ( !Thread.supported() )
        {
            logger.debug( "Cannot run without threads.\n" );
        }
        else
        {
            if ( playbackThread == null )
            {
                try
                {
                    playbackThread = Thread.create<void *>( playbackThreadFunc, true );
                }
                catch ( ThreadError e )
                {
                    stdout.printf( @"Error: $(e.message)" );
                    return;
               }
            }
            else
            {
                stdout.printf( "Thread already launched \n" );
            }
            runPlaybackThread = true;
        }




    }

    private void alsaSrcSetup()
    {
        int channels = 1;
        int rate = 8000;
        Alsa.PcmFormat format = Alsa.PcmFormat.S16_LE;
        Alsa.PcmAccess access = Alsa.PcmAccess.RW_INTERLEAVED;

        pcmin = new FsoAudio.PcmDevice();
        assert( logger.debug( @"Setup alsa source for modem audio" ) );
        try
        {
            pcmin.open( "plug:dsnoop", Alsa.PcmStream.CAPTURE );
            pcmin.setFormat( access, format, rate, channels );
        }
        catch ( Error e )
        {
            logger.error( @"Error: $(e.message)" );
        }

        /* start the record thread now
         */
        if ( !Thread.supported() )
        {
            logger.debug( "Cannot run without threads.\n" );
        }
        else
        {
            if ( recordThread == null )
            {
                try
                {
                    recordThread = Thread.create<void *>( recordThreadFunc, true );
                }
                catch ( ThreadError e )
                {
                    stdout.printf( @"Error: $(e.message)" );
                    return;
               }
            }
            else
            {
                stdout.printf( "Thread already launched \n" );
            }
            runRecordThread = true;
        }

    }

    private void alsaSinkCleanup()
    {
        pcmout.close();
        runPlaybackThread = false;
        playbackThread.join();
        playbackThread = null;

    }

    private void alsaSrcCleanup()
    {
        pcmin.close();
        runRecordThread = false;
        recordThread.join();
        recordThread = null;
    }

    private void handleDataEvent()
    {
        assert( logger.debug( @"handleDataEvent during protocol state $(connection.protocol_state())" ) );

        CmtSpeech.FrameBuffer dlbuf = null;
        CmtSpeech.FrameBuffer ulbuf = null;

        var ok = connection.dl_buffer_acquire( out dlbuf );
        if ( ok == 0 )
        {
            assert( logger.debug( @"received DL packet w/ $(dlbuf.count) bytes" ) );

            Memory.copy(from_modem_to_writei,dlbuf.payload ,dlbuf.pcount);
            updatePtr(out writeiWriteptr,dlbuf.pcount);

            if ( connection.protocol_state() == CmtSpeech.State.ACTIVE_DLUL )
            {
                ok = connection.ul_buffer_acquire( out ulbuf );
                if ( ok == 0 )
                {
                    assert( logger.debug( "protocol state is ACTIVE_DLUL, uploading as well..." ) );

                    Memory.copy(ulbuf.payload,from_readi_to_modem,ulbuf.pcount);
                    updatePtr(out readiReadptr, dlbuf.pcount);
                    connection.ul_buffer_release( ulbuf );
                }
            }
            connection.dl_buffer_release( dlbuf );
        }
    }

    private void handleControlEvent()
    {
        assert( logger.debug( @"handleControlEvent during protocol state $(connection.protocol_state())" ) );

        CmtSpeech.Event event = CmtSpeech.Event();
        CmtSpeech.Transition transition = 0;

        connection.read_event( event );

        assert( logger.debug( @"read event, type is $(event.msg_type)" ) );
        transition = connection.event_to_state_transition( event );

        switch ( transition )
        {
            case CmtSpeech.Transition.INVALID:
                assert( logger.debug( "ERROR: invalid state transition") );
                break;

            case CmtSpeech.Transition.1_CONNECTED:
            case CmtSpeech.Transition.2_DISCONNECTED:
            case CmtSpeech.Transition.3_DL_START:
            case CmtSpeech.Transition.4_DLUL_STOP:
            case CmtSpeech.Transition.5_PARAM_UPDATE:
                assert( logger.debug( @"State transition ok, new state is $transition" ) );
                break;

            case CmtSpeech.Transition.6_TIMING_UPDATE:
            case CmtSpeech.Transition.7_TIMING_UPDATE:
                assert( logger.debug( "WARNING: modem UL timing update ignored" ) );
                break;

            case CmtSpeech.Transition.10_RESET:
            case CmtSpeech.Transition.11_UL_STOP:
            case CmtSpeech.Transition.12_UL_START:
                assert( logger.debug( @"State transition ok, new state is $transition" ) );
                break;

            default:
                assert_not_reached();
                break;
        }
    }

    private bool onInputFromChannel( IOChannel source, IOCondition condition )
    {
        //the following line is commented to work arround a vala 0.12.1 bug
        //with the use of to_string() on an enum, which results in a segmentation fault
        //assert( logger.debug( @"onInputFromChannel, condition = $condition" ) );

        assert( condition == IOCondition.HUP || condition == IOCondition.IN );

        if ( condition == IOCondition.HUP )
        {
            logger.warning( "HUP! Will no longer handle input from cmtspeechdata" );
            return false;
        }

        CmtSpeech.EventType flags = 0;
        var ok = connection.check_pending( out flags );
        if ( ok < 0 )
        {
            assert( logger.debug( "Error while checking for pending events..." ) );
        }
        else if ( ok == 0 )
        {
            assert( logger.debug( "D'oh, cmt speech readable, but no events pending..." ) );
        }
        else
        {
            assert( logger.debug( "Connection reports pending events with flags 0x%0X".printf( flags ) ) );

            if ( ( flags & CmtSpeech.EventType.DL_DATA ) == CmtSpeech.EventType.DL_DATA )
            {
                handleDataEvent();
            }
            else if ( ( flags & CmtSpeech.EventType.CONTROL ) == CmtSpeech.EventType.CONTROL )
            {
                handleControlEvent();
            }
            else
            {
                assert( logger.debug( "Event no DL_DATA nor CONTROL, ignoring" ) );
            }
        }

        return true;
    }

    //
    // Public API
    //

    public override string repr()
    {
        CmtSpeech.State state = ( connection != null ) ? connection.protocol_state() : 0;
        return @"<$state>";
    }

    public void setAudioStatus( bool enabled )
    {
        if ( enabled == status )
        {
            assert( logger.debug( @"Status already $status" ) );
            return;
        }

        assert( logger.debug( @"Setting call status to $enabled" ) );

        if ( enabled )
        {
            alsaSinkSetup();
            alsaSrcSetup();
        }
        else
        {
            alsaSinkCleanup();
            alsaSrcCleanup();
        }

        connection.state_change_call_status( enabled );

        status = enabled;
    }
}

// vim:ts=4:sw=4:expandtab
