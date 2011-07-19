/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

internal const string PROC_SELF_CMDLINE = "/proc/self/cmdline";
internal const string PROC_SELF_EXE     = "/proc/self/exe";
internal const string PROC_CPUINFO      = "/proc/cpuinfo";

internal const uint READ_BUF_SIZE = 1024 * 1024;
internal const int BACKTRACE_SIZE = 50;

internal static string _hardware = null;
internal static string _prefix = null;
internal static string _program = null;

internal static GLib.Regex _keyValueRe = null;

internal static GLib.HashTable<string,void*> _hashtable = null;

namespace FsoFramework.DataSharing
{
    public void setValueForKey( string key, void* val )
    {
        if ( _hashtable == null )
        {
            _hashtable = new GLib.HashTable<string,void*>( GLib.str_hash, GLib.str_equal );
        }
        _hashtable.insert( key, val );
    }

    public void* valueForKey( string key )
    {
        if ( _hashtable == null )
        {
            _hashtable = new GLib.HashTable<string,void*>( GLib.str_hash, GLib.str_equal );
        }
        return _hashtable.lookup( key );
    }
}

namespace FsoFramework.FileHandling
{
    public bool createDirectory( string filename, Posix.mode_t mode )
    {
        return ( Posix.mkdir( filename, mode ) != -1 );
    }

    public bool removeTree( string path )
    {
    #if DEBUG
        debug( "removeTree: %s", path );
    #endif
        var dir = Posix.opendir( path );
        if ( dir == null )
        {
    #if DEBUG
            debug( "can't open dir: %s", path );
    #endif
            return false;
        }
        for ( unowned Posix.DirEnt entry = Posix.readdir( dir ); entry != null; entry = Posix.readdir( dir ) )
        {
            if ( ( "." == (string)entry.d_name ) || ( ".." == (string)entry.d_name ) )
            {
    #if DEBUG
                debug( "skipping %s", (string)entry.d_name );
    #endif
                continue;
            }
    #if DEBUG
            debug( "processing %s", (string)entry.d_name );
    #endif
            var result = Posix.unlink( "%s/%s".printf( path, (string)entry.d_name ) );
            if ( result == 0 )
            {
    #if DEBUG
                debug( "%s removed", (string)entry.d_name );
    #endif
                continue;
            }
            if ( Posix.errno == Posix.EISDIR )
            {
                if ( !removeTree( "%s/%s".printf( path, (string)entry.d_name ) ) )
                {
                    return false;
                }
                continue;
            }
            return false;
        }
        return true;
    }

    public bool isPresent( string filename )
    {
        Posix.Stat structstat;
        return ( Posix.stat( filename, out structstat ) != -1 );
    }

    public string readIfPresent( string filename )
    {
        return isPresent( filename ) ? read( filename ) : "";
    }

    public string[] listDirectory( string dirname )
    {
        var result = new string[] {};
        var dir = Posix.opendir( dirname );
        if ( dir != null )
        {
            unowned Posix.DirEnt dirent = Posix.readdir( dir );
            while ( dirent != null )
            {
                result += (string)dirent.d_name;
                dirent = Posix.readdir( dir );
            }
        }
        return result;
    }

    public string read( string filename )
    {
        char[] buf = new char[READ_BUF_SIZE];

        var fd = Posix.open( filename, Posix.O_RDONLY );
        if ( fd == -1 )
        {
            FsoFramework.theLogger.warning( @"Can't read-open $filename: $(Posix.strerror(Posix.errno))" );
        }
        else
        {
            ssize_t count = Posix.read( fd, buf, READ_BUF_SIZE );
            if ( count < 1 )
            {
                FsoFramework.theLogger.warning( @"Couldn't read anything from $filename: $(Posix.strerror(Posix.errno))" );
                Posix.close( fd );
            }
            else
            {
                Posix.close( fd );
                return ( (string)buf ).strip();
            }
        }
        return "";
    }

    public void write( string contents, string filename, bool create = false )
    {
        Posix.mode_t mode = 0;
        int flags = Posix.O_WRONLY;
        if ( create )
        {
            mode = Posix.S_IRUSR | Posix.S_IWUSR | Posix.S_IRGRP | Posix.S_IROTH;
            flags |= Posix.O_CREAT /* | Posix.O_EXCL */ | Posix.O_TRUNC;
        }
        var fd = Posix.open( filename, flags, mode );
        if ( fd == -1 )
        {
            FsoFramework.theLogger.warning( @"Can't write-open $filename: $(Posix.strerror(Posix.errno))" );
        }
        else
        {
            var length = contents.length;
            ssize_t written = Posix.write( fd, contents, length );
            if ( written != length )
            {
                FsoFramework.theLogger.warning( @"Couldn't write all bytes to $filename ($written of $length)" );
            }
            Posix.close( fd );
        }
    }

    public uint8[] readContentsOfFile( string filename ) throws GLib.FileError
    {
        Posix.Stat structstat;
        var ok = Posix.stat( filename, out structstat );
        if ( ok == -1 )
        {
            throw new GLib.FileError.FAILED( Posix.strerror(Posix.errno) );
        }

        var fd = Posix.open( filename, Posix.O_RDONLY );
        if ( fd == -1 )
        {
            throw new GLib.FileError.FAILED( Posix.strerror(Posix.errno) );
        }

        var buf = new uint8[structstat.st_size];
        var bread = Posix.read( fd, buf, structstat.st_size );
        if ( bread != structstat.st_size )
        {
            Posix.close( fd );
            throw new GLib.FileError.FAILED( @"Short read; got only $bread of $(structstat.st_size)" );
        }

        Posix.close( fd );
        return buf;
    }

    /**
     * Write buffer to file, supports partial writes.
     **/
    public void writeContentsToFile( uint8[] buffer, string filename ) throws GLib.FileError
    {
        var fd = Posix.open( filename, Posix.O_WRONLY );
        if ( fd == -1 )
        {
            throw new GLib.FileError.FAILED( Posix.strerror(Posix.errno) );
        }

        var written = 0;
        uint8* pointer = buffer;

        while ( written < buffer.length )
        {
            var wrote = Posix.write( fd, pointer + written, buffer.length - written );
            if ( wrote <= 0 )
            {
                Posix.close( fd );
                throw new GLib.FileError.FAILED( @"Short write; aborting after writing $written of buffer.length" );
            }
            written += (int)wrote;
        }
        Posix.close( fd );
    }

    public void writeBuffer( void* buffer, ulong length, string filename, bool create = false )
    {
        Posix.mode_t mode = 0;
        int flags = Posix.O_WRONLY;
        if ( create )
        {
            mode = Posix.S_IRUSR | Posix.S_IWUSR | Posix.S_IRGRP | Posix.S_IROTH;
            flags |= Posix.O_CREAT | Posix.O_EXCL;
        }
        var fd = Posix.open( filename, flags, mode );
        if ( fd == -1 )
        {
            FsoFramework.theLogger.warning( @"Can't write-open $filename: $(Posix.strerror(Posix.errno))" );
        }
        else
        {
            ssize_t written = Posix.write( fd, buffer, length );
            if ( written != length )
            {
                FsoFramework.theLogger.warning( @"Couldn't write all bytes to $filename ($written of $length)" );
            }
            Posix.close( fd );
        }
    }
}

namespace FsoFramework.UserGroupHandling
{
    public Posix.uid_t uidForUser( string user )
    {
        Posix.setpwent();
        unowned Posix.Passwd pw = Posix.getpwent();
        while ( pw != null )
        {
            if ( pw.pw_name == user )
                return pw.pw_uid;
            pw = Posix.getpwent();
        }
        return -1;
    }

    public Posix.gid_t gidForGroup( string group )
    {
        Posix.setgrent();
        unowned Posix.Group gr = Posix.getgrent();
        while ( gr != null )
        {
            if ( gr.gr_name == group )
                return gr.gr_gid;
            gr = Posix.getgrent();
        }
        return -1;
    }

    public bool switchToUserAndGroup( string user, string group )
    {
        var uid = uidForUser( user );
        var gid = gidForGroup( group );
        if ( uid == -1 || gid == -1 )
            return false;
        var ok = Posix.setgid( gid );
        if ( ok != 0 )
        {
            FsoFramework.theLogger.warning( @"Can't set group id: $(Posix.strerror(Posix.errno))" );
            return false;
        }
        ok = Posix.setuid( uid );
        if ( ok != 0 )
        {
            FsoFramework.theLogger.warning( @"Can't set user id: $(Posix.strerror(Posix.errno))" );
            return false;
        }
        return true;
    }
}

namespace FsoFramework.StringHandling
{
    //TODO: make this a generic, once Vala supports it
    public string stringListToString( string[] list )
    {
        if ( list.length == 0 )
            return "[]";

        var res = "[ ";

        for( int i = 0; i < list.length; ++i )
        {
            res += "\"%s\"".printf( list[i] );
            if ( i < list.length-1 )
                res += ", ";
            else
                res += " ]";
        }
        return res;
    }

    public T enumFromString<T>( string value, T default_value )
    {
        T result = enumFromName<T>( value );
        if ( ((int) result) == -1 )
        {
            result = enumFromNick<T>( value );
            if ( ((int) result) == -1 )
            {
                result = default_value;
            }
        }
        return result;
    }

    public string enumToString<T>( T value )
    {
        EnumClass ec = (EnumClass) typeof( T ).class_ref();
        unowned EnumValue? ev = ec.get_value( (int)value );
        return ev == null ? "Unknown Enum value for %s: %i".printf( typeof( T ).name(), (int)value ) : ev.value_name;
    }

    public string enumToNick<T>( T value )
    {
        var ec = (EnumClass) typeof(T).class_ref();
        var ev = ec.get_value( (int)value );
        return ev == null ? "Unknown Enum value for %s: %i".printf( typeof( T ).name(), (int)value ) : ev.value_nick;
    }

    public T enumFromName<T>( string name )
    {
        var ec = (EnumClass) typeof(T).class_ref();
        var ev = ec.get_value_by_name( name );
        return ev == null ? -1 : ev.value;
    }

    public T enumFromNick<T>( string nick )
    {
        var ec = (EnumClass) typeof(T).class_ref();
        var ev = ec.get_value_by_nick( nick );
        return ev == null ? -1 : ev.value;
    }

    public T convertEnum<F,T>( F from )
    {
        var s = FsoFramework.StringHandling.enumToNick<F>( from );
        return FsoFramework.StringHandling.enumFromNick<T>( s );
    }

    public GLib.HashTable<string,string> splitKeyValuePairs( string str )
    {
        var result = new GLib.HashTable<string,string>( GLib.str_hash, GLib.str_equal );
        if ( _keyValueRe == null )
        {
            try
            {
                _keyValueRe = new GLib.Regex( "(?P<key>[A-Za-z0-9]+)=(?P<value>[A-Za-z0-9.]+)" );
            }
            catch ( GLib.RegexError e )
            {
                assert_not_reached(); // regex invalid
            }
        }
        GLib.MatchInfo mi;
        var next = _keyValueRe.match( str, GLib.RegexMatchFlags.NEWLINE_CR, out mi );
        while ( next )
        {
    #if DEBUG
            debug( "got match '%s' = '%s'", mi.fetch_named( "key" ), mi.fetch_named( "value" ) );
    #endif
            result.insert( mi.fetch_named( "key" ), mi.fetch_named( "value" ) );
            try
            {
                next = mi.next();
            }
            catch ( GLib.RegexError e )
            {
    #if DEBUG
                debug( @"regex error: $(e.message)" );
    #endif
                next = false;
            }
        }
        return result;
    }

    public string hexdump( uint8[] array, int linelength = 16, string prefix = "", uchar unknownCharacter = '?' )
    {
        if ( array.length < 1 )
        {
            return "";
        }

        string result = "";

        int BYTES_PER_LINE = linelength;

        var hexline = new StringBuilder( prefix );
        var ascline = new StringBuilder();
        uchar b;
        int i;

        for ( i = 0; i < array.length; ++i )
        {
            b = array[i];
            hexline.append_printf( "%02X ", b );
            if ( 31 < b && b < 128 )
                ascline.append_printf( "%c", b );
            else
                ascline.append_printf( "." );

            if ( i % BYTES_PER_LINE+1 == BYTES_PER_LINE )
            {
                hexline.append( ascline.str );
                result += hexline.str;
                result += "\n";
                hexline = new StringBuilder( prefix );
                ascline = new StringBuilder();
            }
        }
        if ( i % BYTES_PER_LINE+1 != BYTES_PER_LINE )
        {
            while ( hexline.len < 3 * BYTES_PER_LINE )
            {
                hexline.append_c( ' ' );
            }

            hexline.append( ascline.str );
            result += hexline.str;
            result += "\n";
        }

        return result.strip();
    }

    public string filterByAllowedCharacters( string input, string allowed )
    {
        var output = "";

        for ( var i = 0; i < input.length; ++i )
        {
            var str = input[i].to_string();
            if ( str in allowed )
            {
                output += str;
            }
        }
        return output;
    }
}

namespace FsoFramework.Utility
{
    const uint BUF_SIZE = 1024; // should be Posix.PATH_MAX

    public string programName()
    {
        if ( _program == null )
        {

            _program = GLib.Environment.get_prgname();
            if ( _program == null )
            {
                char[] buf = new char[BUF_SIZE];
                var length = Posix.readlink( PROC_SELF_EXE, buf );
                buf[length] = 0;
                assert( length != 0 );
                _program = GLib.Path.get_basename( (string) buf );
            }
        }
        return _program;
    }

    public string prefixForExecutable()
    {
        if ( _prefix == null )
        {
            var cmd = FileHandling.read( PROC_SELF_CMDLINE );
            var pte = Environment.find_program_in_path( cmd );
            _prefix = "";

            foreach ( var component in pte.split( "/" ) )
            {
                //debug( "dealing with component '%s', prefix = '%s'", component, _prefix );
                if ( component.has_suffix( "bin" ) )
                    break;
                _prefix += "%s%c".printf( component, Path.DIR_SEPARATOR );
            }
        }
        return _prefix;
    }

    public string[] createBacktrace()
    {
        string[] result = new string[] { };
#if HAVE_BACKTRACE
        void* buffer = malloc0( BACKTRACE_SIZE * sizeof(string) );
        var size = Linux.backtrace( buffer, BACKTRACE_SIZE );
        string[] symbols = Linux.backtrace_symbols( buffer, size );
        result += "--- BACKTRACE (%zd frames) ---\n".printf( size );
        for ( var i = 0; i < size; ++i )
        {
            result += "%s\n".printf( symbols[i] );
        }
        result += "--- END BACKTRACE ---\n";
#else
        result += "BACKTRACE FACILITIES NOT AVAILABLE";
#endif
        return result;
    }

    public string? firstAvailableProgram( string[] candidates )
    {
        for ( int i = 0; i < candidates.length; ++i )
        {
            var pte = Environment.find_program_in_path( candidates[i] );
            if ( pte != null )
            {
                return pte;
            }
        }
        return null;
    }

    public string hardware()
    {
        if ( _hardware != null )
        {
            return _hardware;
        }
        _hardware = "default";

        var proc_cpuinfo = FsoFramework.FileHandling.read( PROC_CPUINFO );
        if ( proc_cpuinfo != "" )
        {
            foreach ( var line in proc_cpuinfo.split( "\n" ) )
            {
                if ( line.has_prefix( "Hardware" ) )
                {
                    var parts = line.split( ": " );
                    _hardware = ( parts.length == 2 ) ? parts[1].strip().replace( " ", "" ) : "unknown";
                    break;
                }
            }
        }
        return _hardware;
    }

    public string machineConfigurationDir()
    {
        return Path.build_filename( Config.SYSCONFDIR, "freesmartphone", "conf", hardware() );;
    }
    public string dataToString(uint8[] data, int limit = -1)
    {
        if (limit == -1 || data.length < limit)
        {
            limit = data.length;
        }

        unowned string str = (string)data;

        return str.ndup(limit);
    }

    public int copyData( ref uint8[] destination, uint8[] source, int limit = -1 )
    {
        int length = destination.length;
        if( limit >= 0 && limit < length )
             length = limit;
        if( length > source.length )
             length = source.length;
        GLib.Memory.copy( destination, source, length );

        destination.length = length;

        return length;
    }
}

namespace FsoFramework.Async
{
    /**
     * @class EventFd
     **/
    [Compact]
    public class EventFd
    {
        public GLib.IOChannel channel;
        public uint watch;

        public EventFd( uint initvalue, GLib.IOFunc callback )
        {
            channel = new GLib.IOChannel.unix_new( Linux.eventfd( initvalue, 0 ) );
            watch = channel.add_watch( GLib.IOCondition.IN, callback );
        }

        public void write( int count )
        {
            Linux.eventfd_write( channel.unix_get_fd(), count );
        }

        public uint read()
        {
            uint64 result;
            Linux.eventfd_read( channel.unix_get_fd(), out result );
            return (uint)result;
        }

        ~EventFd()
        {
            Source.remove( watch );
            channel = null;
        }
    }

    /**
     * @class ReactorChannel
     **/
    public class ReactorChannel : GLib.Object
    {
        public delegate void ActionFunc( void* data, ssize_t length );
        private int fd;
        private uint watch;
        private GLib.IOChannel channel;
        private ActionFunc actionfunc;
        private char[] buffer;
        private bool rewind_flag;

        private void init( int fd, owned ActionFunc actionfunc, size_t bufferlength = 512 )
        {
            assert( fd > -1 );
            channel = new GLib.IOChannel.unix_new( fd );
            assert( channel != null );
            this.fd = fd;
            this.actionfunc = actionfunc;
            buffer = new char[ bufferlength ];
        }

        public ReactorChannel( int fd, owned ActionFunc actionfunc, size_t bufferlength = 512 )
        {
            init( fd, actionfunc, bufferlength );
            watch = channel.add_watch( GLib.IOCondition.IN | GLib.IOCondition.HUP, onActionFromChannel );
            this.rewind_flag = false;
        }

        public ReactorChannel.rewind( int fd, owned ActionFunc actionfunc, size_t bufferlength = 512 )
        {
            init( fd, actionfunc, bufferlength );
            watch = channel.add_watch( GLib.IOCondition.IN | GLib.IOCondition.PRI | GLib.IOCondition.HUP, onActionFromChannel );
            this.rewind_flag = true;
        }

        public int fileno()
        {
            return fd;
        }

        //
        // private API
        //
        ~ReactorChannel()
        {
            channel = null;
            GLib.Source.remove( watch );
            Posix.close( fd );
        }

        private bool onActionFromChannel( GLib.IOChannel source, GLib.IOCondition condition )
        {
            if ( ( condition & IOCondition.HUP ) == IOCondition.HUP )
            {
                // On exceptional condition, the delegate is being called with (null, 0) to do
                // whatever necessary to bring us back on track.
                actionfunc( null, 0 );
                return false;
            }

            if ( ( ( condition & IOCondition.IN  ) == IOCondition.IN  ) ||
                 ( ( condition & IOCondition.PRI ) == IOCondition.PRI ) )
            {
                assert( fd != -1 );
                assert( buffer != null );
                if( rewind_flag ) Posix.lseek(fd, 0, Posix.SEEK_SET);
                ssize_t bytesread = Posix.read( fd, buffer, buffer.length );
                actionfunc( buffer, bytesread );
                return true;
            }

            FsoFramework.theLogger.error( "Unsupported IOCondition %u".printf( (int)condition ) );
            return true;
        }
    }

    public async void sleep_async( int timeout, GLib.Cancellable? cancellable = null )
    {
        ulong cancel = 0;
        uint timeout_src = 0;
        bool interrupted = false;
        if( cancellable != null )
        {
            if ( cancellable.is_cancelled() )
                return;
            cancel = cancellable.cancelled.connect( () =>
                {
                    interrupted = true;
                    sleep_async.callback();
                } );
        }

        timeout_src = Timeout.add( timeout, sleep_async.callback );
        yield;
        Source.remove (timeout_src);

        if (cancel != 0 && ! interrupted)
        {
            cancellable.disconnect( cancel );
        }
    }
}

namespace FsoFramework.Network
{
    public async string[]? textForUri( string servername, string uri = "/" ) throws GLib.Error
    {
        var result = new string[] {};

        var resolver = Resolver.get_default();
        List<InetAddress> addresses = null;
        try
        {
             addresses = yield resolver.lookup_by_name_async( servername, null );
        }
        catch ( Error e )
        {
            FsoFramework.theLogger.warning( @"Could not resolve server address $(e.message)" );
            return null;
        }
        var serveraddr = addresses.nth_data( 0 );
        assert( FsoFramework.theLogger.debug( @"Resolved $servername to $serveraddr" ) );

        var socket = new InetSocketAddress( serveraddr, 80 );
        var client = new SocketClient();
        var conn = yield client.connect_async( socket, null );

        assert( FsoFramework.theLogger.debug( @"Connected to $serveraddr" ) );

        var message = @"GET $uri HTTP/1.1\r\nHost: $servername\r\nConnection: close\r\n\r\n";
        yield conn.output_stream.write_async( message.data );
        assert( FsoFramework.theLogger.debug( @"Wrote request" ) );

        conn.socket.set_blocking( true );
        var input = new DataInputStream( conn.input_stream );

        var line = ( yield input.read_line_async( 0, null, null ) ).strip();
        assert( FsoFramework.theLogger.debug( @"Received status line: $line" ) );

        if ( ! ( line.has_prefix( "HTTP/1.1 200 OK" ) ) )
        {
            return null;
        }

        // skip headers
        while ( line != null && line != "\r" && line != "\r\n" )
        {
            line = yield input.read_line_async( 0, null, null );
            if ( line != null )
            {
                assert( FsoFramework.theLogger.debug( @"Received header line: $(line.escape( """""" ) )" ) );
            }
        }

        while ( line != null )
        {
            line = yield input.read_line_async( 0, null, null );
            if ( line != null && line != "\r" && line != "\r\n" && line != "" )
            {
                assert( FsoFramework.theLogger.debug( @"Received content line: $line" ) );
                result += line.strip();
            }
        }
        return result;
    }
}

// vim:ts=4:sw=4:expandtab
