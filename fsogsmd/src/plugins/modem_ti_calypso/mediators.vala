/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

namespace TiCalypso
{

/**
 * Monitor Mediators
 **/
public class AtMonitorGetServingCellInformation : MonitorGetServingCellInformation
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = modem.createAtCommand<PercentEM21>( "%EM21" );
        var response = yield modem.processAtCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );

        cell = new GLib.HashTable<string,GLib.Variant>( GLib.str_hash, GLib.str_equal );

        cell.insert( "arfcn", cmd.arfcn );
        cell.insert( "c1", cmd.c1 );
        cell.insert( "c2", cmd.c2 );
        cell.insert( "rxlev", cmd.rxlev );
        cell.insert( "bsic", cmd.bsic );
        cell.insert( "cid", cmd.cid );
        cell.insert( "dsc", cmd.dsc );
        cell.insert( "txlev", cmd.txlev );
        cell.insert( "tn", cmd.tn );
        cell.insert( "rlt", cmd.rlt );
        cell.insert( "tav", cmd.tav );
        cell.insert( "rxlev_f", cmd.rxlev_f );
        cell.insert( "rxlev_s", cmd.rxlev_s );
        cell.insert( "rxqual_f", cmd.rxqual_f );
        cell.insert( "rxqual_s", cmd.rxqual_s );
        cell.insert( "lac", cmd.lac );
        cell.insert( "cba", cmd.cba );
        cell.insert( "cbq", cmd.cbq );
        cell.insert( "ctype", cmd.ctype );
        cell.insert( "vocoder", cmd.vocoder );
    }
}

public class AtMonitorGetNeighbourCellInformation : MonitorGetNeighbourCellInformation
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = modem.createAtCommand<PercentEM23>( "%EM23" );
        var response = yield modem.processAtCommandAsync( cmd, cmd.query() );
        checkMultiResponseValid( cmd, response );

        //cells = new GLib.HashTable<string,GLib.Variant>[] {};
        cells = new GLib.HashTable<string,GLib.Variant>[cmd.valid] {};

        for ( int i = 0; i < cmd.valid; ++i )
        {
            var cell = new GLib.HashTable<string,GLib.Variant>( GLib.str_hash, GLib.str_equal );

            cell.insert( "arfcn", cmd.arfcn[i] );
            cell.insert( "c1", cmd.c1[i] );
            cell.insert( "c2", cmd.c2[i] );
            cell.insert( "rxlev", cmd.rxlev[i] );
            cell.insert( "bsic", cmd.bsic[i] );
            cell.insert( "cid", cmd.cid[i] );
            cell.insert( "lac", cmd.lac[i] );
            cell.insert( "foffset", cmd.foffset[i] );
            cell.insert( "timea", cmd.timea[i] );
            cell.insert( "cba", cmd.cba[i] );
            cell.insert( "cbq", cmd.cbq[i] );
            cell.insert( "ctype", cmd.ctype[i] );
            cell.insert( "rac", cmd.rac[i] );
            cell.insert( "roffset", cmd.roffset[i] );
            cell.insert( "toffset", cmd.toffset[i] );
            cell.insert( "rxlevam", cmd.rxlevam[i] );

            cells[i] = cell;
            //cells.append( cell );
        }
    }
}

public class AtSimGetUnlockCounters : SimGetUnlockCounters
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = modem.createAtCommand<PercentPVRF>( "%PVRF" );
        var response = yield modem.processAtCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );
        counters = new GLib.HashTable<string,GLib.Variant>( GLib.str_hash, GLib.str_equal );
        counters.insert( "SIM PIN", cmd.pin );
        counters.insert( "SIM PIN2", cmd.pin2 );
        counters.insert( "SIM PUK", cmd.puk );
        counters.insert( "SIM PUK2", cmd.puk2 );
    }
}

public class AtVoiceMailboxGetNumber : VoiceMailboxGetNumber
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var cmd = modem.createAtCommand<PercentCPMB>( "%CPMB" );
        var response = yield modem.processAtCommandAsync( cmd, cmd.query() );
        checkResponseValid( cmd, response );
        number = cmd.number;
    }
}

/**
 * Register all mediators
 **/
public void registerCustomMediators( HashMap<Type,Type> table )
{
    table[ typeof(MonitorGetServingCellInformation) ]   = typeof( AtMonitorGetServingCellInformation );
    table[ typeof(MonitorGetNeighbourCellInformation) ] = typeof( AtMonitorGetNeighbourCellInformation );
    table[ typeof(SimGetUnlockCounters) ]               = typeof( TiCalypso.AtSimGetUnlockCounters );
    table[ typeof(VoiceMailboxGetNumber) ]              = typeof( TiCalypso.AtVoiceMailboxGetNumber );
}

} /* namespace TiCalypso */

// vim:ts=4:sw=4:expandtab
