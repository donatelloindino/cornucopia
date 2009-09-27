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
 * AT Command Interface and Abstract Base Class.
 *
 * The AtCommand class encapsulate generation and parsing of every kind of AT
 * command strings. To generate a command, use issue() or query(). The response
 * is to be fed into the parse() method. At commands are parsed using regular
 * expressions. The resulting fields are then picked into member variables.
 **/

public errordomain FsoGsm.AtCommandError
{
    UNABLE_TO_PARSE,
}

public abstract interface FsoGsm.AtCommand : GLib.Object
{
    public abstract void parse( string response ) throws AtCommandError;
    public abstract bool is_valid_prefix( string line );
}

public abstract class FsoGsm.AbstractAtCommand : FsoGsm.AtCommand, GLib.Object
{
    protected Regex re;
    protected MatchInfo mi;
    protected string[] prefix;

    public virtual void parse( string response ) throws AtCommandError
    {
        bool match;
        match = re.match( response, 0, out mi );

        if ( !match || mi == null )
            throw new AtCommandError.UNABLE_TO_PARSE( "%s does not match against RE %s".printf( response, re.get_pattern() ) );
    }

    protected string to_string( string name )
    {
        var res = mi.fetch_named( name );
        if ( res == null )
            return ""; // indicates parameter not present
        return res;
    }

    protected int to_int( string name )
    {
        var res = mi.fetch_named( name );
        if ( res == null )
            return -1; // indicates parameter not present
        return res.to_int();
    }

    public bool is_valid_prefix( string line )
    {
        if ( prefix == null ) // free format
            return true;
        for ( int i = 0; i < prefix.length; ++i )
        {
            if ( line.has_prefix( prefix[i] ) )
                return true;
        }
        return false;
    }
}

public class FsoGsm.SimpleAtCommand<T> : FsoGsm.AbstractAtCommand
{
    public T value;
    private string name;

    public SimpleAtCommand( string name, bool prefixoptional = false )
    {
        this.name = name;
        var regex = prefixoptional ? """(\%s:\ )?""".printf( name ) : """\%s:\ """.printf( name );

        if ( typeof(T) == typeof(string) )
        {
            regex += """"?(?P<righthandside>[^"]*)"?""";
        }
        else if ( typeof(T) == typeof(int) )
        {
            regex += """(?P<righthandside>\d)""";
        }
        else
        {
            assert_not_reached();
        }
        if ( !prefixoptional )
        {
            prefix = { name + ": " };
        }
        re = new Regex( regex );
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        if ( typeof(T) == typeof(string) )
        {
            value = to_string( "righthandside" );
        }
        else if ( typeof(T) == typeof(int) )
        {
            value = to_int( "righthandside" );
        }
        else
        {
            assert_not_reached();
        }
    }

    public string execute()
    {
        return name;
    }

    public string query()
    {
        return name + "?";
    }
}

public class FsoGsm.NullAtCommand : FsoGsm.AbstractAtCommand
{
}
