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
 * This file contains AT command specifications defined the official 3GPP GSM
 * specifications, such as 05.05 and 07.07.
 *
 * Do _not_ add vendor-specific commands here, instead add them to your modem plugin.
 **/

using Gee;

namespace FsoGsm {

public class PlusCBC : AbstractAtCommand
{
    public string status;
    public int level;

    public PlusCBC()
    {
        re = new Regex( """\+CBC: (?P<status>\d),(?P<level>\d+)""" );
        prefix = { "+CBC: " };
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        status = Constants.instance().devicePowerStatusToString( to_int( "status" ) );
        level = to_int( "level" );
    }

    public string execute()
    {
        return "+CBC";
    }
}

public class PlusCFUN : SimpleAtCommand<int>
{
    public PlusCFUN()
    {
        base( "+CFUN" );
    }
}

public class PlusCGCLASS : SimpleAtCommand<string>
{
    public PlusCGCLASS()
    {
        base( "+CGCLASS" );
    }
}

public class PlusCGMI : SimpleAtCommand<string>
{
    public PlusCGMI()
    {
        base( "+CGMI", true );
    }
}

public class PlusCGMM : SimpleAtCommand<string>
{
    public PlusCGMM()
    {
        base( "+CGMM", true );
    }
}

public class PlusCGMR : SimpleAtCommand<string>
{
    public PlusCGMR()
    {
        base( "+CGMR", true );
    }
}

public class PlusCGSN : SimpleAtCommand<string>
{
    public PlusCGSN()
    {
        base( "+CGSN", true );
    }
}

public class PlusCLVL : SimpleAtCommand<int>
{
    public PlusCLVL()
    {
        base( "+CLVL" );
    }
}

public class PlusCNMI : AbstractAtCommand
{
    public int mode;
    public int mt;
    public int bm;
    public int ds;
    public int bfr;

    public PlusCNMI()
    {
        re = new Regex( """\+CNMI: (?P<mode>\d),(?P<mt>\d),(?P<bm>\d),(?P<ds>\d),(?P<bfr>\d)""" );
        prefix = { "+CNMI: " };
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        mode = to_int( "mode" );
        mt = to_int( "mt" );
        bm = to_int( "bm" );
        ds = to_int( "ds" );
        bfr = to_int( "bfr" );
    }

    public string query()
    {
        return "+CNMI?";
    }

    public string issue( int mode, int mt, int bm, int ds, int bfr )
    {
        return "+CNMI=%d,%d,%d,%d,%d".printf( mode, mt, bm, ds, bfr );
    }
}

public class PlusCMICKEY : SimpleAtCommand<int>
{
    public PlusCMICKEY()
    {
        base( "+CMICKEY" );
    }
}

public class PlusCMUT : SimpleAtCommand<int>
{
    public PlusCMUT()
    {
        base( "+CMUT" );
    }
}

public class PlusCOPS_Test : AbstractAtCommand
{
    public struct Provider
    {
        public string status;
        public string shortname;
        public string longname;
        public string mccmnc;
        public string act;
    }
    Provider[] providers;

    public PlusCOPS_Test()
    {
        re = new Regex( """\((?P<status>\d),"(?P<longname>[^"]*)","(?P<shortname>[^"]*)","(?P<mccmnc>[^"]*)"(?:,(?P<act>\d))?\)""" );
        prefix = { "+COPS: " };
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        providers = new Provider[] {};
        do
        {
            var p = Provider() {
                status = Constants.instance().networkProviderStatusToString( to_int( "status" ) ),
                longname = to_string( "longname" ),
                shortname = to_string( "shortname" ),
                mccmnc = to_string( "mccmnc" ),
                act = Constants.instance().networkProviderActToString( to_int( "act" ) ) };
            providers += p;
        }
        while ( mi.next() );
    }

    public string issue()
    {
        return "+COPS=?";
    }

    public FreeSmartphone.GSM.NetworkProvider[] providerList()
    {
        return (FreeSmartphone.GSM.NetworkProvider[]) providers;
    }
}

public class PlusCPIN : AbstractAtCommand
{
    public string pin;

    public PlusCPIN()
    {
        re = new Regex( """\+CPIN:\ "?(?P<pin>[^"]*)"?""" );
        prefix = { "+CPIN: " };
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        pin = to_string( "pin" );
    }

    public string issue( string pin, string? new_pin = null )
    {
        if ( new_pin == null )
            return "+CPIN=\"%s\"".printf( pin );
        else
            return "+CPIN=\"%s\",\"%s\"".printf( pin, new_pin );
    }

    public string query()
    {
        return "+COPS?";
    }
}

public class PlusFCLASS : AbstractAtCommand
{
    public string faxclass;

    public PlusFCLASS()
    {
        re = new Regex( """"?(?P<faxclass>[^"]*)"?""" );
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        faxclass = to_string( "faxclass" );
    }

    public string query()
    {
        return "+FCLASS?";
    }

    public string test()
    {
        return "+FCLASS=?";
    }
}

public class PlusCOPS : AbstractAtCommand
{
    public int status;
    public int mode;
    public string oper;

    public PlusCOPS()
    {
        re = new Regex( """\+COPS:\ (?P<status>\d)(,(?P<mode>\d)?(,"(?P<oper>[^"]*)")?)?""" );
        prefix = { "+COPS: " };
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        status = to_int( "status" );
        mode = to_int( "mode" );
        oper = to_string( "oper" );
    }

    public string issue( int mode, int format, int oper = 0 )
    {
        if ( oper == 0 )
            return "+CFUN=%d,%d".printf( mode, format );
        else
            return "+CFUN=%d,%d,\"%d\"".printf( mode, format, oper );
    }

    public string query()
    {
        return "+COPS?";
    }
}

public class PlusGCAP : SimpleAtCommand<string>
{
    public PlusGCAP()
    {
        base( "+GCAP", true );
    }
}

public void registerGenericAtCommands( HashMap<string,AtCommand> table )
{
    // register commands
    table[ "+CBC" ]              = new FsoGsm.PlusCBC();
    table[ "+CFUN" ]             = new FsoGsm.PlusCFUN();
    table[ "+CGCLASS" ]          = new FsoGsm.PlusCGCLASS();
    table[ "+CGMI" ]             = new FsoGsm.PlusCGMI();
    table[ "+CGMM" ]             = new FsoGsm.PlusCGMM();
    table[ "+CGMR" ]             = new FsoGsm.PlusCGMR();
    table[ "+CGSN" ]             = new FsoGsm.PlusCGSN();
    table[ "+CLVL" ]             = new FsoGsm.PlusCLVL();
    table[ "+CMICKEY" ]          = new FsoGsm.PlusCMICKEY();
    table[ "+CMUT" ]             = new FsoGsm.PlusCMUT();
    table[ "+CNMI" ]             = new FsoGsm.PlusCNMI();
    table[ "+COPS" ]             = new FsoGsm.PlusCOPS();
    table[ "+COPS=?" ]           = new FsoGsm.PlusCOPS_Test();
    table[ "+CPIN" ]             = new FsoGsm.PlusCPIN();
    table[ "+FCLASS" ]           = new FsoGsm.PlusFCLASS();
    table[ "+GCAP" ]             = new FsoGsm.PlusGCAP();
}

} /* namespace FsoGsm */
