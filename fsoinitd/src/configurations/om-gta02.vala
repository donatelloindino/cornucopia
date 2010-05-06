/**
 * -- freesmartphone.org boot utility --
 *
 * Copyright (C) 2010 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 **/

namespace FsoInit {

public BaseConfiguration createMachineConfiguration() 
{
	return new GTA02Configuration();
}

public class GTA02Configuration : BaseConfiguration
{
	construct
	{
		name = "om-gta02";
	}

	public override void registerActionsInQueue(IActionQueue queue)
	{
		// Mount proc and sysfs filesystem
		queue.registerAction(new SpawnProcessAction.with_settings("mount -o remount,rw /"));
		queue.registerAction(new MountFilesystemAction.with_settings((Posix.mode_t) 0555, "proc", "/proc", "proc", Linux.MountFlags.MS_SILENT));
		queue.registerAction(new MountFilesystemAction.with_settings((Posix.mode_t) 0755, "sys", "/sys", "sysfs", Linux.MountFlags.MS_SILENT | Linux.MountFlags.MS_NOEXEC | Linux.MountFlags.MS_NODEV | Linux.MountFlags.MS_NOSUID ));
        
		// Turn led on, so the user know the init process has been started
		queue.registerAction(new SysfsConfigAction.with_settings("/sys/class/leds/gta02-aux:red/brightness", "50"));
		
		// Mount relevant filesystems
		queue.registerAction(new MountFilesystemAction.with_settings((Posix.mode_t) 0755, "devtmpfs", "/dev", "devtmpfs", Linux.MountFlags.MS_SILENT | Linux.MountFlags.MS_NOEXEC | Linux.MountFlags.MS_NODEV | Linux.MountFlags.MS_NOSUID ));
		queue.registerAction(new MountFilesystemAction.with_settings((Posix.mode_t) 0755, "tmpfs", "/tmp", "tmpfs", Linux.MountFlags.MS_SILENT));
		queue.registerAction(new MountFilesystemAction.with_settings((Posix.mode_t) 0755, "devpts", "/dev/pts", "devpts", Linux.MountFlags.MS_SILENT | Linux.MountFlags.MS_NOEXEC | Linux.MountFlags.MS_NODEV | Linux.MountFlags.MS_NOSUID ));
		
		// Configure network interface
		queue.registerAction(new ConfigureNetworkInterfaceAction.with_settings("lo", "127.0.0.1", "255.255.255.0"));
		queue.registerAction(new ConfigureNetworkInterfaceAction.with_settings("usb0", "192.168.0.202", "255.255.255.0"));
		
		// Launch several other daemons we need right after the init process is over
		queue.registerAction(new SpawnProcessAction.with_settings("dbus --system --fork"));
		queue.registerAction(new SpawnProcessAction.with_settings("/etc/init.d/fsodeviced start"));
		queue.registerAction(new SpawnProcessAction.with_settings("/etc/init.d/fsotdld start"));
		queue.registerAction(new SpawnProcessAction.with_settings("/etc/init.d/sshd start"));
		queue.registerAction(new SpawnProcessAction.with_settings("/etc/init.d/phonefsod start"));
		queue.registerAction(new SpawnProcessAction.with_settings("/etc/init.d/xserver-nodm start"));
		
		// Turn led off to let the user know we have finished
		queue.registerAction(new SysfsConfigAction.with_settings("/sys/class/leds/gta02-aux:red/brightness", "0"));
	}
}

} // namespace


