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
 **/

/**
 * @class MuxPppPdpHandler
 *
 * This PppHandler uses ppp over a multiplexed line to implement the Pdp handler interface
 **/
public class FsoGsm.MuxPppPdpHandler : FsoGsm.PdpHandler, FsoFramework.AbstractObject
{
    private FsoFramework.GProcessGuard ppp;
    private LibGsm0710muxTransport transport;

    public override string repr()
    {
        return "<>";
    }

    private void onPppStopped()
    {
        //FIXME: check for expected or unexpected stop
        logger.debug( "ppp has been stopped" );
    }

    //
    // public API
    //
    public MuxPppPdpHandler( LibGsm0710muxTransport transport )
    {
        this.transport = transport;
    }

    public async void activate() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        if ( ppp != null && ppp.isRunning() )
        {
            return;
        }

        // build ppp command line
        var data = theModem.data();
        var cmdline = new string[] { data.pppCommand };

        // check whether we should use a pipe or not
        var port = theModem.allocateDataPort();
        var intport = port.to_int();
        if ( intport > 0 )
        {
            logger.info( @"Using pppd in PIPE mode via fd $(intport)" );
        }
        else
        {
            cmdline += port;
        }

        // add modem specific options to command line
        foreach ( var option in data.pppOptions )
        {
            cmdline += option;
        }

        /*
        // prepare modem
        var cmd = theModem.createAtCommand<V250D>( "D" );
        var response = yield theModem.processCommandAsync( cmd, cmd.issue( "*99#" ) );
        checkResponseOk( cmd, response );
        */

        // launch ppp
        ppp = new FsoFramework.GProcessGuard();
        ppp.stopped.connect( onPppStopped );

        if ( intport > 0 )
        {
            ppp.launch( cmdline );
        }
        else
        {
            ppp.launchWithPipe( cmdline, intport );
        }
    }

    public async void deactivate()
    {
        if ( ppp == null )
        {
            return;
        }
        if ( !ppp.isRunning() )
        {
            return;
        }
        ppp = null; // this will stop the process
    }
}
