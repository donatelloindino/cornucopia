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
using Gee;
using FsoFramework;

namespace FsoAudio
{
    private const uint16 TOKEN_BASE = 0x2300;
    private uint16 token_counter = 0x0;

    public class SessionHandler : AbstractObject
    {
        private HashMap<string,FreeSmartphone.Audio.Stream> sessions;
        private AbstractAudioSessionPolicy policy;

        construct
        {
            sessions = new HashMap<string,FreeSmartphone.Audio.Stream>();
        }

        public SessionHandler( AbstractAudioSessionPolicy policy )
        {
            this.policy = policy;
        }

        public override string repr()
        {
            return "<>";
        }

        public string register_session( FreeSmartphone.Audio.Stream stream ) throws FreeSmartphone.Error
        {
            string token = "";

            token = new_token();
            if ( token in sessions.keys )
            {
                throw new FreeSmartphone.Error.INTERNAL_ERROR( "We have two session with exactly the same key! WTF!?" );
            }

            sessions.set( token, stream );
            logger.debug( @"Successfully registered a new audio session: token = $(token), stream = $(stream)" );

            return token;
        }

        public void release_session( string token ) throws FreeSmartphone.Error
        {
            if ( !( token in sessions.keys ) )
            {
                throw new FreeSmartphone.Error.INVALID_PARAMETER( "Supplied unknown token for audio session" );
            }

            sessions.unset( token );
        }

        private string new_token()
        {
            return "%x".printf( TOKEN_BASE + token_counter++ );
        }
    }
}

// vim:ts=4:sw=4:expandtab
