/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2014 Sebastian Krzyszkowiak <dos@dosowisko.net>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using FsoGsm;
using Gee;

namespace CinterionPS8
{

/**
 * +VTS: DTMF and tone generationm
 * PS8 requires the argument to be enclosed in quotation marks.
 **/
public class CinterionPlusVTS : PlusVTS
{
    public new string issue( string tones )
    {
        var command = @"+VTS=\"$(tones[0])\"";
        for ( var n = 1; n < tones.length; n++ )
            command += @";+VTS=\"$(tones[n])\"";
        return command;
    }
}

/**
 * +CSCA: SMS Service Center Address
 * PS8 returns the number encoded with current channel charset
 **/
public class CinterionPlusCSCA : PlusCSCA
{
    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        number = Constants.phonenumberTupleToString( decodeString( to_string( "number" ) ), to_int( "ntype" ) );
    }

    public new string issue( string number )
    {
        return "+CSCA=\"%s\",%d".printf( encodeString( number ), Constants.determinePhoneNumberType( number ) );
    }
}

/**
 * Register all custom commands
 **/
public void registerCustomAtCommands( HashMap<string,AtCommand> table )
{
    table[ "+VTS" ]           = new CinterionPlusVTS();
    table[ "+CSCA" ]          = new CinterionPlusCSCA();
}

} /* namespace CinterionPS8 */

// vim:ts=4:sw=4:expandtab
