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
 * @interface FsoFramework.IProcessGuard
 **/
public interface FsoFramework.IProcessGuard : GLib.Object
{
    public abstract bool launch( string[] command );
    public abstract void kill( int sig = Posix.SIGTERM );

    public signal void running( FsoFramework.IProcessGuard self );
    public signal void stopped( FsoFramework.IProcessGuard self );
}

/**
 * @class FsoFramework.GProcessGuard
 **/
public class FsoFramework.GProcessGuard : FsoFramework.IProcessGuard, GLib.Object
{
    private Pid pid;
    private uint watch;

    public bool launch( string[] command )
    {
        if ( pid != (Pid)0 )
        {
            warning( @"Can't launch $(command[0]); already running as pid %d".printf( (int)pid ) );
            return false;
        }

        var res = 0;
        try
        {
            GLib.Process.spawn_async( GLib.Environment.get_variable( "PWD" ),
                                      command,
                                      null,
                                      GLib.SpawnFlags.DO_NOT_REAP_CHILD | GLib.SpawnFlags.SEARCH_PATH,
                                      null,
                                      out pid );
        }
        catch ( SpawnError e )
        {
            warning( @"Can't spawn $(command[0]): $(strerror(errno))" );
            return false;
        }

        watch = GLib.ChildWatch.add( pid, onChildWatchEvent );
        this.running( this ); // SIGNAL
        return true;
    }

    public void kill( int sig = Posix.SIGTERM )
    {
        GLib.Process.close_pid( pid );
        Posix.kill( (Posix.pid_t)pid, sig );
        if ( watch > 0 )
        {
            GLib.Source.remove( watch );
        }
    }

    //
    // private API
    //
    public void onChildWatchEvent( Pid pid, int status )
    {
#if DEBUG
        debug( "CHILD WATCH EVENT FOR %d: %d", (int)pid, status );
#endif
        assert( this.pid == pid );
        this.stopped( this ); // SIGNAL
    }
}
