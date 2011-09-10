/**
 * Copyright (C) 2011 Simon Busch <morphis@gravedo.de>
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

using GLib;
using FsoFramework;

void test_jsonreader_all()
{
    var file = File.new_for_path( "test-all.json" );
    var stream = file.read( null );

    var reader = new FsoEvents.JsonReader( stream );
}

void main (string[] args)
{
    Test.init (ref args);

    Test.add_func("/JsonReader/all", test_jsonreader_all);

    Test.run();
}

// vim:ts=4:sw=4:expandtab
