=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require_relative 'connection/error'
require_relative 'connection/callbacks'
require_relative 'connection/peer_info'
require_relative 'connection/tls'

module Arachni
class Reactor

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Connection
    include Callbacks

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

    # @return   [Bool, nil]
    #   `true` when using a UNIX-domain socket, `nil` if no {#socket} is
    #   available, `false` otherwise.
    def unix?
        return @is_unix if !@is_unix.nil?
        return if !to_io
        return false if !Arachni::Reactor.supports_unix_sockets?

        @is_unix = to_io.is_a?( UNIXServer ) || to_io.is_a?( UNIXSocket )
    end

    # @return   [Bool]
    #   `true` when using an Internet socket, `nil` if no {#socket} is
    #   available, `false` otherwise.
    def inet?
        return @is_inet if !@is_inet.nil?
        return if !to_io

        @is_inet = to_io.is_a?( TCPServer ) || to_io.is_a?( TCPSocket ) || to_io.is_a?( Socket )
    end

    # @return   [IO, nil]
    #   IO stream or `nil` if no {#socket} is available.
    def to_io
        return if !@socket
        @socket.to_io
    end

    # @return   [Bool]
    #   `true` if the connection is a server listener.
    def listener?
        return @is_listener if !@is_listener.nil?
        return if !to_io

        @is_listener = to_io.is_a?( TCPServer ) || (unix? && to_io.is_a?( UNIXServer ))
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

        if listener? && unix? && (path = to_io.path) && File.exist?( path )
            File.delete( path )
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

    # Accepts a new client connection.
    #
    # @return   [Connection, nil]
    #   New connection or `nil` if the socket isn't ready to accept new
    #   connections yet.
    #
    # @private
    def accept
        return if !(accepted = socket_accept)

        connection = @server_handler.call
        connection.configure socket: accepted, role: :server
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
    def configure( options = {} )
        @socket         = options[:socket]
        @role           = options[:role]
        @host           = options[:host]
        @port           = options[:port]
        @server_handler = options[:server_handler]

        # If we're a server without a handler then we're an accepted connection.
        if unix? || role == :server
            @connected = true
            on_connect
        end

        nil
    end

    def connected?
        !!@connected
    end

    # @private
    def _connect
        return true if unix? || connected?

        begin
            Error.translate do
                socket.connect_nonblock( Socket.sockaddr_in( @port, @host ) )
            end
        # Already connected. :)
        rescue Errno::EISCONN, Errno::EALREADY
        end

        @connected = true
        on_connect

        true
    rescue IO::WaitReadable, IO::WaitWritable, Errno::EINPROGRESS
    rescue Error => e
        close e
    end

    # @note If this is a server {#listener?} it will delegate to {#accept}.
    # @note If this is a normal socket it will read {BLOCK_SIZE} amount of data.
    #   and pass it to {#on_read}.
    #
    # Processes a `read` event for this connection.
    #
    # @private
    def _read
        return _connect if !listener? && !connected?
        return accept   if listener?

        Error.translate do
            on_read @socket.read_nonblock( BLOCK_SIZE )
        end

    # Not ready to read or write yet, we'll catch it on future Reactor ticks.
    rescue IO::WaitReadable, IO::WaitWritable
    rescue Error => e
        close e
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
        return _connect if !connected?

        chunk = write_buffer.byteslice( 0, BLOCK_SIZE )
        total_written = 0

        begin
            Error.translate do
                # Send out the chunk, **all** of it, or at least try to.
                loop do
                    total_written += written = @socket.write_nonblock( chunk )
                    @write_buffer = @write_buffer.byteslice( written..-1 )

                    # Call #on_write every time any of the buffer is consumed.
                    on_write

                    break if written == chunk.bytesize
                    chunk = chunk.byteslice( written..-1 )
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
