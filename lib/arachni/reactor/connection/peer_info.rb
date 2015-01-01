=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Connection

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module PeerInfo

    # @param    [Bool]  resolve
    #   Resolve IP address to hostname.
    # @return   [Hash]
    #   Peer address information:
    #
    #   * IP socket:
    #       * Without `resolve`:
    #
    #               {
    #                   protocol:   'AF_INET',
    #                   port:       10314,
    #                   hostname:   '127.0.0.1',
    #                   ip_address: '127.0.0.1'
    #               }
    #
    #       * With `resolve`:
    #
    #               {
    #                   protocol:   'AF_INET',
    #                   port:       10314,
    #                   hostname:   'localhost',
    #                   ip_address: '127.0.0.1'
    #               }
    #
    #   * UNIX-domain socket:
    #
    #           {
    #               protocol: 'AF_UNIX',
    #               path:     '/tmp/my-socket'
    #           }
    def peer_address_info( resolve = false )
        if Arachni::Reactor.supports_unix_sockets? && to_io.is_a?( UNIXSocket )
            {
                protocol: to_io.peeraddr.first,
                path:     to_io.path
            }
        else
            protocol, port, hostname, ip_address = to_io.peeraddr( resolve )

            {
                protocol:   protocol,
                port:       port,
                hostname:   hostname,
                ip_address: ip_address
            }
        end
    end

    # @return   [String]
    #   Peer's IP address or socket path.
    def peer_address
        peer_ip_address || peer_address_info[:path]
    end

    # @return   [String]
    #   Peer's IP address.
    def peer_ip_address
        peer_address_info[:ip_address]
    end

    # @return   [String]
    #   Peer's hostname.
    def peer_hostname
        peer_address_info(true)[:hostname]
    end

    # @return   [String]
    #   Peer's port.
    def peer_port
        peer_address_info[:port]
    end

end

end
end
end
