/**
 * Copyright (C) 2010 Simon Busch <morphis@gravedo.de>
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

namespace FsoInit {

public class SpawnProcessAction : IAction, GLib.Object
{
	public string name { get { return "SpawnProcessAction"; } }
	public string cmdline { get; set; }
	public bool inBackground { get; set; default = false; }
	
	construct
	{
	}
	
	public SpawnProcessAction.with_settings(string cmdline, bool inBackground = false) {
		this.cmdline = cmdline;
		this.inBackground = inBackground;
	}

	public string to_string() 
	{
		return @"[$(name)] :: cmdline = '$(cmdline)'";
	}

	public void run() throws ActionError
	{
		int res = 0; string command = cmdline;
		if (inBackground) {
			command = @"$(cmdline) &";
		}

		res = Posix.system(command);

		if (res < 0) 
		{
			var msg = "Could not spawn process '";
			msg += cmdline.length > 1 ? cmdline : "<unknown>";
			msg += "'";
			throw new ActionError.COULD_NOT_SPAWN_PROCESS(msg);
		}
	}

	public void reset() throws ActionError
	{
		// FIXME what to do here?
	}
}

} // namespace


