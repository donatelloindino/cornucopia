/* libnl-2.0.vapi
 *
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

[CCode (lower_case_cprefix = "nl_", cheader_filename = "netlink/netlink.h")]
namespace Netlink {

    [CCode (instance_pos = -1)]
    public delegate void Callback (Object obj);

    [Compact]
    [CCode (cprefix = "nl_addr_", cname = "struct nl_addr", free_function = "", cheader_filename = "netlink/addr.h")]
    public class Address : Object {
        [CCode (cname = "nl_addr_alloc")]
        public Address();

        public void     put();
        public int      build_add_request (int a, out Message m);
        public int      build_delete_request (int a, out Message m);

        public int      set_label (string label);
        public string   get_label ();

        public void     set_family (int family);
        public int      get_family ();

        public int      get_len ();

        public void     set_prefixlen (int len);
        public int      get_prefixlen ();

        public void     set_flags (uint flags);
        public void     unset_flags (uint flags);
        public uint     get_flags ();

        public void*    get_binary_addr();

        [CCode (cname = "nl_addr2str")]
        public weak string to_stringbuf(char[] buf);

        public string to_string() {
            char[] buf = new char[256];
            return to_stringbuf( buf );
        }
    }

    [Compact]
    [CCode (cprefix = "rtnl_addr_", cname = "struct rtnl_addr", free_function = "", cheader_filename = "netlink/route/addr.h")]
    public class RouteAddress : Address {
        [CCode (cname = "rtnl_addr_alloc")]
        public RouteAddress();

        public void     set_ifindex (int index );
        public int      get_ifindex ();

        public void     set_scope (int scope);
        public int      get_scope ();

        public weak Address get_local();
    }

    [Compact]
    [CCode (cprefix = "nl_cache_", cname = "struct nl_cache", free_function = "nl_cache_free", cheader_filename = "netlink/cache.h")]
    public class Cache {
        public static int alloc_name (string name, out Cache c);

        public void @foreach (Callback cb);
        public void foreach_filter (Object obj, Callback cb);
    }

    [Compact]
    [CCode (cprefix = "nl_link_cache_", cname = "struct nl_cache", free_function = "nl_cache_free", cheader_filename = "netlink/cache.h")]
    public class LinkCache : Cache {
        [CCode (cname = "rtnl_link_name2i")]
        public int name2i (string name);
    }

    [Compact]
    [CCode (cprefix = "nl_addr_cache", cname = "struct nl_cache", free_function = "nl_cache_free", cheader_filename = "netlink/cache.h")]
    public class AddrCache : Cache {
    }

    [Compact]
    [CCode (cname = "struct nl_msg", free_function = "nl_msg_free", cheader_filename = "netlink/msg.h")]
    public class Message {
    }

    [Compact]
    [CCode (cprefix = "nl_socket_", cname = "struct nl_sock", free_function = "nl_socket_free")]
    public class Socket {
        [CCode (cname = "nl_socket_alloc")]
        public Socket();

        [CCode (cname = "rtnl_link_alloc_cache")]
        public int              link_alloc_cache (out LinkCache c);
        [CCode (cname = "rtnl_addr_alloc_cache")]
        public int              addr_alloc_cache (out AddrCache c);

        [CCode (cname = "nl_connect")]
        public int              connect (int family);
        [CCode (cname = "nl_join_groups")]
        public void             join_groups (int groups);

        public int              add_memberships (int group, ...);
        public int              add_membership (int group);
        public int              drop_memberships (int group, ...);
        public int              drop_membership (int group);
        public uint32           get_peer_port ();
        public void             set_peer_port (uint32 port);

        /*
        public struct nl_cb *   get_cb();
        public void             set_cb(struct nl_cb *);
        public int              modify_cb(, enum nl_cb_type,
                                                    enum nl_cb_kind,
                                                    nl_recvmsg_msg_cb_t, void *);
        */

        public int              set_buffer_size (int rxbuf, int txbuf);
        public int              set_passcred (bool on);
        public int              recv_pktinfo (bool on);

        public void             disable_seq_check ();
        public uint             use_seq ();
        public void             disable_auto_ack ();
        public void             enable_auto_ack ();

        public int              get_fd ();
        public int              set_nonblocking ();
        public void             enable_msg_peek ();
        public void             disable_msg_peek ();
    }

    [Compact]
    [CCode (cname = "struct nl_object", free_function = "nl_object_free", cheader_filename = "netlink/object.h")]
    public class Object {
    }

}
