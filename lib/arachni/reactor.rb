=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require 'socket'
require 'openssl'

module Arachni

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Reactor

    # {Reactor} error namespace.
    #
    # All {Reactor} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < StandardError

        # Raised when trying to perform an operation that requires the Reactor
        # to be running when it is not.
        #
        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class NotRunning < Error
        end

        # Raised when trying to run an already running loop.
        #
        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class AlreadyRunning < Error
        end

    end

    %w(connection tasks queue).each do |f|
        require_relative "reactor/#{f}"
    end

    # @return     [Integer,nil]
    #   Amount of time to wait for a connection.
    attr_accessor :max_tick_interval

    # @return     [Array<Connection>]
    #   {#attach Attached} connections.
    attr_reader   :connections

    # @return     [Integer]
    attr_reader   :ticks

    DEFAULT_OPTIONS = {
        max_tick_interval: 0.1
    }

    class <<self

        # @return   [Reactor]
        #   Singleton Reactor.
        def global
            @reactor ||= new
        end
    end
    # Global/Singleton Reactor at the ready!
    global

    # @param    [Hash]  options
    # @option   [Integer,nil]   :max_tick_interval    (0.1)
    #   Maximum amount of time for each iteration of the Reactor loop. Basically
    #   sets the timeout value for the `Kernel.select` call as that's our only
    #   constant blocker.
    def initialize( options = {} )
        options = DEFAULT_OPTIONS.merge( options )

        @max_tick_interval = options[:max_tick_interval]

        # Socket => Connection
        @connections = {}
        @stop        = false
        @ticks       = 0
        @thread      = nil
        @tasks       = Tasks.new
    end

    # @return   [Reactor::Queue]
    #   New {Reactor::Queue} with `self` as the scheduler.
    def create_queue
        Reactor::Queue.new self
    end

    # @note {Connection::Error Connection errors} will be passed to the `handler`'s
    #   {Connection#on_close} method as a `reason` argument.
    #
    # Connects to a peer.
    #
    # @overload  connect( host, port, handler = Connection, *handler_options )
    #   @param    [String]    host
    #   @param    [Integer]   port
    #   @param    [Connection]   handler
    #       Connection handler, should be a subclass of {Connection}.
    #   @param    [Hash]   handler_options
    #       Options to pass to the `#initialize` method of the `handler`.
    #
    # @overload  connect( unix_socket, handler = Connection, *handler_options )
    #   @param    [String]    unix_socket
    #       Path to the UNIX socket to connect.
    #   @param    [Connection]   handler
    #       Connection handler, should be a subclass of {Connection}.
    #   @param    [Hash]   handler_options
    #       Options to pass to the `#initialize` method of the `handler`.
    #
    # @return   [Connection]
    #   Connected instance of `handler`.
    def connect( *args )
        options = determine_connection_options( *args )

        connection = options[:handler].new( *options[:handler_options] )
        connection.reactor = self

        begin
            Connection::Error.translate do
                socket = options[:unix_socket] ?
                    connect_unix( options[:unix_socket] ) :
                    connect_tcp( options[:host], options[:port] )

                connection.configure socket, :client
            end
        rescue Connection::Error => e
            connection.close e
        end

        connection
    end

    # Listens for incoming connections.
    #
    # @overload  listen( host, port, handler = Connection, *handler_options )
    #   @param    [String]    host
    #   @param    [Integer]   port
    #   @param    [Connection]   handler
    #       Connection handler, should be a subclass of {Connection}.
    #   @param    [Hash]   handler_options
    #       Options to pass to the `#initialize` method of the `handler`.
    #
    #   @raise    [Connection::Error::HostNotFound]
    #       If the `host` is invalid.
    #   @raise    [Connection::Error::Permission]
    #       If the `port` could not be opened due to a permission error.
    #
    # @overload  listen( unix_socket, handler = Connection, *handler_options )
    #   @param    [String]    unix_socket
    #       Path to the UNIX socket to create.
    #   @param    [Connection]   handler
    #       Connection handler, should be a subclass of {Connection}.
    #   @param    [Hash]   handler_options
    #       Options to pass to the `#initialize` method of the `handler`.
    #
    #   @raise    [Connection::Error::Permission]
    #       If the `unix_socket` file could not be created due to a permission error.
    #
    # @return   [Connection]
    #   Listening instance of `handler`.
    def listen( *args )
        options = determine_connection_options( *args )

        Connection::Error.translate do
            server_handler = proc do
                options[:handler].new( *options[:handler_options] )
            end

            @server = server_handler.call
            @server.reactor = self

            socket = options[:unix_socket] ?
                listen_unix( options[:unix_socket] ) :
                listen_tcp( options[:host], options[:port] )

            @server.configure socket, :server, server_handler
        end

        @server
    end

    # @return   [Bool]
    #   `true` if the {Reactor} is {#run running}, `false` otherwise.
    def running?
        !!thread
    end

    # Stops the {Reactor} {#run loop} at the next tick.
    def stop
        schedule { @stop = true }
    end

    # @note Will simply return if already {#running?}.
    # @note If already {#running?} and a `block` is given it will be forwarded
    #   to {#next_tick}.
    #
    # Starts the {Reactor} loop and blocks the current {#thread} until {#stop}
    # is called.
    #
    # @param    [Block] block
    #   Block to call right before initializing the loop.
    def run( &block )
        if running?
            schedule( &block ) if block_given?
            return
        end

        @thread = Thread.current

        block.call if block_given?

        while !@stop
            process_connections

            @tasks.call
            @ticks += 1
        end

        @tasks.clear
        close_connections
        shutdown_server

        @ticks  = 0
        @thread = nil
    end

    # Starts the {#run Reactor loop}, blocks the current {#thread} while the
    # given `block` executes and then {#stop}s it.
    #
    # @param    [Block] block
    #   Block to call.
    #
    # @raise    [Error::AlreadyRunning]
    #   If already running.
    def run_block( &block )
        fail ArgumentError, 'Missing block.' if !block_given?
        fail Error::AlreadyRunning, 'The reactor is already running.' if running?

        run do
            block.call
            next_tick { stop }
        end
    end

    # @param    [Block] block
    #   Schedules a {Tasks::Persistent task} to be run at each tick.
    def on_tick( &block )
        @tasks << Tasks::Persistent.new( &block )
        nil
    end

    # @param    [Block] block
    #   Schedules a task to be run as soon as possible, either immediately if
    #   the caller is {#in_same_thread? in the same thread}, or at the
    #   {#next_tick} otherwise.
    def schedule( &block )
        if running? && in_same_thread?
            block.call
        else
            next_tick(&block)
        end

        nil
    end

    # @param    [Block] block
    #   Schedules a {Tasks::OneOff task} to be run at the next tick.
    def next_tick( &block )
        @tasks << Tasks::OneOff.new( &block )
        nil
    end

    # @note Time accuracy cannot be guaranteed.
    #
    # @param    [Float] interval
    #   Time in seconds.
    # @param    [Block] block
    #   Schedules a {Tasks::Periodic task} to be run at every `interval` seconds.
    def at_interval( interval, &block )
        @tasks << Tasks::Periodic.new( interval, &block )
        nil
    end

    # @note Time accuracy cannot be guaranteed.
    #
    # @param    [Float] time
    #   Time in seconds.
    # @param    [Block] block
    #   Schedules a {Tasks::Delayed task} to be run in `time` seconds.
    def delay( time, &block )
        @tasks << Tasks::Delayed.new( time, &block )
        nil
    end

    # @return   [Thread, nil]
    #   Thread of the {#run loop}, `nil` if not running.
    def thread
        @thread
    end

    # @return   [Bool]
    #   `true` if the caller is in the same {#thread} as the {#run reactor loop},
    #   `false` otherwise.
    def in_same_thread?
        fail Error::NotRunning if !running?
        Thread.current == thread
    end

    # Attaches a connection to the {Reactor} loop.
    #
    # @param    [Connection]    connection
    def attach( connection )
        @connections[connection.socket] = connection
    end

    # Detaches a connection from the {Reactor} loop.
    #
    # @param    [Connection]    connection
    def detach( connection )
        @connections.delete connection.socket
    end

    private

    def process_connections
        # Get connections with available events - :read, :write, :error.
        selected = select_connections

        # Close connections that have errors.
        [selected.delete(:error)].flatten.compact.each(&:close)

        # Call the corresponding event on the connections.
        selected.each { |event, connections| connections.each(&event) }
    end

    def determine_connection_options( *args )
        options = {}
        host = port = unix_socket = nil

        if args[1].is_a? Integer
            options[:host], options[:port], options[:handler], *handler_options = *args
        else
            options[:unix_socket], options[:handler], *handler_options = *args
        end

        if !options[:unix_socket].is_a?( String ) &&
            (!options[:host].is_a?( String ) || !options[:port].is_a?( Integer ))
            fail ArgumentError,
                 'Either a UNIX socket path or a host and port combination are required.'
        end

        options[:handler]       ||= Connection
        options[:handler_options] = handler_options
        options
    end

    # @return   [UNIXSocket]
    #   Connected socket.
    def connect_unix( unix_socket )
        UNIXSocket.new( unix_socket )
    end

    # @return   [Socket]
    #   Connected socket.
    def connect_tcp( host, port )
        socket = Socket.new(
            Socket::Constants::AF_INET,
            Socket::Constants::SOCK_STREAM,
            Socket::Constants::IPPROTO_IP
        )
        socket.do_not_reverse_lookup = true

        begin
            socket.connect_nonblock( Socket.sockaddr_in( port, host ) )
        rescue IO::WaitReadable, IO::WaitWritable
        end

        socket
    end

    # @return   [TCPServer]
    #   Listening server socket.
    def listen_tcp( host, port )
        server = TCPServer.new( host, port )
        server.do_not_reverse_lookup = true
        server
    end

    # @return   [UNIXServer]
    #   Listening server socket.
    def listen_unix( unix_socket )
        UNIXServer.new( unix_socket )
    end

    # Closes all client connections, both ingress and egress.
    def close_connections
        @connections.values.each(&:close_without_callback)
    end

    # Shuts down the server.
    def shutdown_server
        return if !@server

        @server.close
        @server = @server_handler = nil
    end

    # @return   [Hash]
    #
    #   Connections grouped by their available events:
    #
    #   * `:read` -- Ready for reading (i.e. with data in their incoming buffer).
    #   * `:write` -- Ready for writing (i.e. with data in their
    #       {Connection#has_outgoing_data? outgoing buffer).
    #   * `:error`
    def select_connections
        grouped_sockets = select(
            read_sockets,
            write_sockets,
            read_sockets, # Read sockets are actually all sockets.
            @max_tick_interval
        )
        return {} if !grouped_sockets

        {
            # Since these will be processed in order, it's better have the write
            # ones first to flush the buffers ASAP.
            write: connections_from_sockets( grouped_sockets[1] ),
            read:  connections_from_sockets( grouped_sockets[0] ),
            error: connections_from_sockets( grouped_sockets[2] )
        }
    end

    # @return   [Array<Socket>]
    #   Sockets of all connections, we want to be ready to read at any time.
    def read_sockets
        @connections.keys
    end

    # @return   [Array<Socket>]
    #   Sockets of connections with
    #   {Connection#has_outgoing_data? outgoing data}.
    def write_sockets
        @connections.map do |socket, connection|
            next if !connection.has_outgoing_data?
            socket
        end.compact
    end

    def connections_from_sockets( sockets )
        sockets.map { |s| connection_from_socket( s ) }
    end

    def connection_from_socket( socket )
        @connections[socket]
    end

end

end
