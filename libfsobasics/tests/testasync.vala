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

using GLib;
using FsoFramework;

MainLoop loop;

Linux.Input.Event event; // not using it, but needed to make the sizeof call (see below) succeed

//===========================================================================
void test_async_reactorchannel()
//===========================================================================
{
    loop = new MainLoop();

    var fd = Posix.open( "/dev/input/event4", Posix.O_RDONLY );
    var chan = new Async.ReactorChannel( fd, IOCondition.IN, sizeof( Linux.Input.Event ), ( data, length ) => {
        debug( @"got $length bytes of data" );
        loop.quit();
    } );

    loop.run();
}

//===========================================================================
void main (string[] args)
//===========================================================================
{
    Test.init (ref args);

    Test.add_func( "/Async/ReactorChannel", test_async_reactorchannel );

    Test.run ();
}
