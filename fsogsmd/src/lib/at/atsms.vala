/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

using Gee;

/**
 * @class AtSmsHandler
 **/
public class FsoGsm.AtSmsHandler : FsoGsm.AbstractSmsHandler
{
    private bool ack_supported = true;
    private bool supported = true;

    //
    // protected
    //

    protected override async string retrieveImsiFromSIM()
    {
        var cimi = theModem.createAtCommand<PlusCIMI>( "+CIMI" );
        var response = yield theModem.processAtCommandAsync( cimi, cimi.execute() );
        if ( cimi.validate( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( "Can't retrieve IMSI from SIM to be used as identifier for SMS storage" );
            return "";
        }
        return cimi.value;
    }

    protected override async void fillStorageWithMessageFromSIM()
    {
        var cmgl = theModem.createAtCommand<PlusCMGL>( "+CMGL" );
        var cmglresponse = yield theModem.processAtCommandAsync( cmgl, cmgl.issue( PlusCMGL.Mode.ALL ) );
        if ( cmgl.validateMulti( cmglresponse ) != Constants.AtResponse.VALID )
        {
            logger.warning( "Can't synchronize SMS storage with SIM" );
            return;
        }

        foreach( var sms in cmgl.messagebook )
        {
            var ret = storage.addSms( sms.message );
            // send the incoming_text_message signal if ret == 1 (message is new).
            if ( ret == 1 )
            {
                var msg = storage.message( sms.message.hash() );
                var obj = theModem.theDevice<FreeSmartphone.GSM.SMS>();
                obj.incoming_text_message( msg.number, msg.timestamp, msg.contents );
            }
        }
    }

    protected override async bool readSmsMessageFromSIM( uint index, out string hexpdu, out int tpdulen )
    {
        hexpdu = "";
        tpdulen = 0;

        var cmd = theModem.createAtCommand<PlusCMGR>( "+CMGR" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( index ) );
        if ( cmd.validateUrcPdu( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( @"Can't read new SMS from SIM storage at index $index." );
            return false;
        }

        hexpdu = cmd.hexpdu;
        tpdulen = cmd.tpdulen;

        return true;
    }

    protected override async bool acknowledgeSmsMessage()
    {
        if ( ! ack_supported )
        {
            assert( logger.debug( @"Skipping SMS acknowledgement because it's disabled" ) );
            return true;
        }

        var cmd = theModem.createAtCommand<PlusCNMA>( "+CNMA" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( 0 ) );
        if ( cmd.validate( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( @"Failed to acknowledge SMS message; further SMS message handling will maybe faulty!" );
            return false;
        }

        return true;
    }

    //
    // public
    //

    public AtSmsHandler()
    {
        base();
    }

    public override async void configure()
    {
        base.configure();

        // First we're gathing which types of SMS services are supported and select the
        // one which suites best for our needs.
        var csms = theModem.createAtCommand<PlusCSMS>( "+CSMS" );
        // Try to enable GSM phase 2+ commands
        var response = yield theModem.processAtCommandAsync( csms, csms.issue( 1 ) );
        if ( csms.validateOk( response ) != Constants.AtResponse.OK )
        {
            logger.warning( @"Desired SMS service mode is not available; SMS acknowledgement support will be disabled." );
            ack_supported = false;

            response = yield theModem.processAtCommandAsync( csms, csms.issue( 0 ) );
            if ( csms.validateOk( response ) != Constants.AtResponse.OK )
            {
                logger.error( @"Could not set minimal SMS service mode; SMS support will be disabled" );
                supported = false;
                return;
            }
        }
    }

    public override string repr()
    {
        return storage != null ? storage.repr() : "<None>";
    }
}

// vim:ts=4:sw=4:expandtab
