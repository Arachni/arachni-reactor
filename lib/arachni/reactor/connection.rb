=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require_relative 'connection/error'
require_relative 'connection/tls'

module Arachni
class Reactor

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Connection

    # Maximum amount of data to be written or read at a time.
    #
    # We set this to the same max block size as the OpenSSL buffers because more
    # than this tends to cause SSL errors and broken #select behavior --
    # 1024 * 16 at the time of writing.
    BLOCK_SIZE = OpenSSL::Buffering::BLOCK_SIZE

    # @return     [Socket]
    #   Ruby `Socket` associated with this connection.
    attr_reader   :socket

    # @return     [Reactor]
    #   Reactor associated with this connection.
    attr_accessor :reactor

    # @return     [Symbol]
    #   `:client` or `:server`
    attr_reader   :role

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
        if Arachni::Reactor.supports_unix_sockets? &&
            @socket.to_io.is_a?( UNIXSocket )

            protocol, _ = @socket.to_io.peeraddr
            {
                protocol: protocol,
                path:     @socket.to_io.path
            }
        else
            protocol, port, hostname, ip_address =
                @socket.to_io.peeraddr( resolve )

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

    # @note The data will be buffered and sent in future {Reactor} ticks.
    #
    # @param    [String]    data
    #   Data to send to the peer.
    def write( data )
        @reactor.schedule do
            write_buffer << data
        end
    end

    # Called after the connection has been established.
    #
    # @abstract
    def on_connect
    end

    # Called after the connection has been attached to a {#reactor}.
    #
    # @abstract
    def on_attach
    end

    # Called right the connection is detached from the {#reactor}.
    #
    # @abstract
    def on_detach
    end

    # @note If a connection could not be established no {#socket} may be
    #   available.
    #
    # Called when the connection gets closed.
    #
    # @param    [Exception] reason
    #   Reason for the close.
    #
    # @abstract
    def on_close( reason )
    end

    # Called when data are available.
    #
    # @param    [String] data
    #   Incoming data.
    #
    # @abstract
    def on_read( data )
    end

    # Called after each {#write} call.
    #
    # @abstract
    def on_write
    end

    # Called after the {#write buffered data} have all been sent to the peer.
    #
    # @abstract
    def on_flush
    end

    # @return   [Bool]
    #   `true` if the connection is {Reactor#attached?} to a {#reactor},
    #   `false` otherwise.
    def attached?
        @reactor && @reactor.attached?( self )
    end

    # @return   [Bool]
    #   `true` if the connection is not {Reactor#attached?} to a {#reactor},
    #   `false` otherwise.
    def detached?
        !attached?
    end

    # @note Will first detach if already {#attached?}.
    # @note Sets {#reactor}.
    # @note Calls {#on_attach}.
    #
    # @param    [Reactor]   reactor
    #   {Reactor} to which to attach {Reactor#attach}.
    #
    # @return   [Bool]
    #   `true` if the connection was attached, `nil` if the connection was
    #   already attached.
    def attach( reactor )
        return if reactor.attached?( self )
        detach if attached?

        reactor.attach self

        true
    end

    # @note Removes {#reactor}.
    # @note Calls {#on_detach}.
    #
    # {Reactor#detach Detaches} `self` from the {#reactor}.
    #
    # @return   [Bool]
    #   `true` if the connection was detached, `nil` if the connection was
    #   already detached.
    def detach
        return if detached?

        @reactor.detach self

        true
    end

    # @note Will not call {#on_close}.
    #
    # Closes the connection and {#detach detaches} it from the {Reactor}.
    def close_without_callback
        return if closed?
        @closed = true

        if @role == :server && @server_handler
            path = nil
            if @reactor.class.supports_unix_sockets? && @socket &&
                (io = @socket.to_io).is_a?( UNIXSocket )
                path = io.path
            end

            File.delete( path ) if path
        end

        if @socket
            @socket.close rescue nil
        end

        detach

        nil
    end

    # @return   [Bool]
    #   `true` if the connection has been {#close closed}, `false` otherwise.
    def closed?
        !!@closed
    end

    # @return   [Bool]
    #   `true` if the connection has {#write outgoing data} that have not
    #   yet been {#write written}, `false` otherwise.
    def has_outgoing_data?
        !write_buffer.empty?
    end

    # @note Will call {#on_close} right before closing the socket and detaching
    #   from the Reactor.
    #
    # Closes the connection and {Reactor#detach detaches} it from the {Reactor}.
    #
    # @param    [Exception] reason
    #   Reason for the close.
    def close( reason = nil )
        return if closed?

        on_close reason
        close_without_callback
        nil
    end

    # @note Will call {#on_write} every time any of the buffer is consumed,
    #   can be multiple times when performing partial writes.
    # @note Will call {#on_flush} once all of the buffer has been consumed.
    #
    # Processes a `write` event for this connection.
    #
    # Consumes and writes {BLOCK_SIZE} amount of data from the the beginning of
    # the {#write} buffer to the socket.
    #
    # @return   [Integer]
    #   Amount of the buffer consumed.
    #
    # @private
    def _write
        chunk = write_buffer.slice( 0, BLOCK_SIZE )
        total_written = 0

        begin
            Error.translate do
                # Send out the buffer, **all** of it, or at least try to.
                loop do
                    total_written += written = @socket.write_nonblock( chunk )
                    write_buffer.slice!( 0, written )

                    # Call #on_write every time any of the buffer is consumed.
                    on_write

                    break if written == chunk.size
                    chunk.slice!( 0, written )
                end
            end

        # Not ready to read or write yet, we'll catch it on future Reactor ticks.
        rescue IO::WaitReadable, IO::WaitWritable
        end

        if write_buffer.empty?
            @socket.flush
            on_flush
        end

        total_written
    rescue Error => e
        close e
    end

    # @note If this is a server listener it will delegate to {#accept}.
    # @note If this is a normal socket it will read {BLOCK_SIZE} amount of data.
    #   and pass it to {#on_read}.
    #
    # Processes a `read` event for this connection.
    #
    # @private
    def _read
        return accept if @role == :server && @server_handler

        Error.translate do
            on_read @socket.read_nonblock( BLOCK_SIZE )
        end

    # Not ready to read or write yet, we'll catch it on future Reactor ticks.
    rescue IO::WaitReadable, IO::WaitWritable
    rescue Error => e
        close e
    end

    # Accepts a new client connection.
    #
    # @return   [Connection, nil]
    #   New connection or `nil` if the socket isn't ready to accept new
    #   connections yet.
    #
    # @private
    def accept
        return if !accepted = socket_accept

        connection = @server_handler.call
        connection.configure accepted, :server
        @reactor.attach connection
        connection
    end

    # @param    [Socket]    socket
    #   Ruby `Socket` associated with this connection.
    # @param    [Symbol]    role
    #   `:server` or `:client`.
    # @param    [Block]    server_handler
    #   Block that generates a handler as specified in {Reactor#listen}.
    #
    # @private
    def configure( socket, role, server_handler = nil )
        @socket         = socket
        @role           = role
        @server_handler = server_handler

        on_connect

        nil
    end

    private

    def write_buffer
        @write_buffer ||= ''
    end

    # Accepts a new client connection.
    #
    # @return   [Socket, nil]
    #   New connection or `nil` if the socket isn't ready to accept new
    #   connections yet.
    #
    # @private
    def socket_accept
        begin
            @socket.accept_nonblock
        rescue IO::WaitReadable, IO::WaitWritable
        end
    end

end

end
end
