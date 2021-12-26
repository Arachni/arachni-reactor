=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require 'socket'
require 'openssl'

module Arachni

# Reactor scheduler and and resource factory.
#
# You're probably interested in:
#
#   * Getting access to a shared and {.global globally accessible Reactor} --
#       that's probably what you want.
#       * Rest of the class methods can be used to manage it.
#   * Creating resources like:
#       * Cross-thread, non-blocking {#create_queue Queues}.
#       * Asynchronous, concurrent {#create_iterator Iterators}.
#       * Network connections to:
#           * {#connect Connect} to a server.
#           * {#listen Listen} for clients.
#       * Tasks to be scheduled:
#           * {#schedule As soon as possible}.
#           * {#on_tick On every loop iteration}.
#           * {#delay After a configured delay}.
#           * {#at_interval Every few seconds}.
#           * {#on_shutdown During shutdown}.
#
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

        # Raised when trying to use UNIX-domain sockets on a host OS that
        # does not support them.
        #
        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class UNIXSocketsNotSupported < Error
        end

    end

    %w(connection tasks queue iterator global).each do |f|
        require_relative "reactor/#{f}"
    end

    # @return     [Integer,nil]
    #   Amount of time to wait for a connection.
    attr_accessor :max_tick_interval

    # @return     [Array<Connection>]
    #   {#attach Attached} connections.
    attr_reader   :connections

    # @return     [Integer]
    #   Amount of ticks.
    attr_reader   :ticks

    DEFAULT_OPTIONS = {
        select_timeout:    0.02,
        max_tick_interval: 0.02
    }

    class <<self

        # @return   [Reactor]
        #   Lazy-loaded, globally accessible Reactor.
        def global
            @reactor ||= Global.instance
        end

        # Stops the {.global global Reactor} instance and destroys it. The next
        # call to {.global} will return a new instance.
        def stop
            return if !@reactor

            global.stop rescue Error::NotRunning

            # Admittedly not the cleanest solution, but that's the only way to
            # force a Singleton to re-initialize -- and we want the Singleton to
            # cleanly implement the pattern in a Thread-safe way.
            global.class.instance_variable_set(:@singleton__instance__, nil)

            @reactor = nil
        end

        def supports_unix_sockets?
            return false if jruby?

            !!UNIXSocket
        rescue NameError
            false
        end

        def jruby?
            RUBY_PLATFORM == 'java'
        end
    end

    # @param    [Hash]  options
    # @option   options  [Integer,nil]   :max_tick_interval    (0.02)
    #   How long to wait for each tick when no connections are available for
    #   processing.
    # @option   options  [Integer]   :select_timeout    (0.02)
    #   How long to wait for connection activity before continuing to the next
    #   tick.
    def initialize( options = {} )
        options = DEFAULT_OPTIONS.merge( options )

        @max_tick_interval = options[:max_tick_interval]
        @select_timeout    = options[:select_timeout]

        # Socket => Connection
        @connections = {}
        @stop        = false
        @ticks       = 0
        @thread      = nil
        @tasks       = Tasks.new

        @error_handlers = Tasks.new
        @shutdown_tasks = Tasks.new
        @done_signal    = ::Queue.new
    end

    # @return   [Reactor::Iterator]
    #   New {Reactor::Iterator} with `self` as the scheduler.
    # @param    [#to_a] list
    #   List to iterate.
    # @param    [Integer]   concurrency
    #   Parallel workers to spawn.
    def create_iterator( list, concurrency = 1 )
        Reactor::Iterator.new( self, list, concurrency )
    end

    # @return   [Reactor::Queue]
    #   New {Reactor::Queue} with `self` as the scheduler.
    def create_queue
        Reactor::Queue.new self
    end

    # @note {Connection::Error Connection errors} will be passed to the `handler`'s
    #   {Connection::Callbacks#on_close} method as a `reason` argument.
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
    #
    # @raise    (see #fail_if_not_running)
    # @raise    (see #fail_if_non_unix)
    def connect( *args, &block )
        fail_if_not_running

        options = determine_connection_options( *args )

        connection = options[:handler].new( *options[:handler_options] )
        connection.reactor = self
        block.call connection if block_given?

        begin
            Connection::Error.translate do
                socket = options[:unix_socket] ?
                    connect_unix( options[:unix_socket] ) : connect_tcp

                connection.configure options.merge( socket: socket, role: :client )
                attach connection
            end
        rescue Connection::Error => e
            connection.close e
        end

        connection
    end

    # @note {Connection::Error Connection errors} will be passed to the `handler`'s
    #   {Connection::Callbacks#on_close} method as a `reason` argument.
    #
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
    #
    # @raise    (see #fail_if_not_running)
    # @raise    (see #fail_if_non_unix)
    def listen( *args, &block )
        fail_if_not_running

        options = determine_connection_options( *args )

        server_handler = proc do
            c = options[:handler].new( *options[:handler_options] )
            c.reactor = self
            block.call c if block_given?
            c
        end

        server = server_handler.call

        begin
            Connection::Error.translate do
                socket = options[:unix_socket] ?
                    listen_unix( options[:unix_socket] ) :
                    listen_tcp( options[:host], options[:port] )

                server.configure options.merge( socket: socket, role: :server, server_handler: server_handler )
                attach server
            end
        rescue Connection::Error => e
            server.close e
        end

        server
    end

    # @return   [Bool]
    #   `true` if the {Reactor} is {#run running}, `false` otherwise.
    def running?
        thread && thread.alive?
    end

    # Stops the {Reactor} {#run loop} {#schedule as soon as possible}.
    #
    # @raise    (see #fail_if_not_running)
    def stop
        schedule { @stop = true }
    end

    # Starts the {Reactor} loop and blocks the current {#thread} until {#stop}
    # is called.
    #
    # @param    [Block] block
    #   Block to call right before initializing the loop.
    #
    # @raise    (see #fail_if_running)
    def run( &block )
        fail_if_running

        @done_signal.clear

        @thread = Thread.current

        block.call if block_given?

        loop do
            begin
                @tasks.call
            rescue => e
                @error_handlers.call( e )
            end
            break if @stop

            begin
                process_connections
            rescue => e
                @error_handlers.call( e )
            end
            break if @stop

            @ticks += 1
        end

        @tasks.clear
        close_connections

        @shutdown_tasks.call

        @ticks  = 0
        @thread = nil

        @done_signal << nil
    end

    # {#run Runs} the Reactor in a thread and blocks until it is {#running?}.
    #
    # @param    (see #run)
    #
    # @return   [Thread]
    #   {Reactor#thread}
    #
    # @raise    (see #fail_if_running)
    def run_in_thread( &block )
        fail_if_running

        Thread.new do
            begin
                run(&block)
            rescue => e
                @error_handlers.call( e )
            end
        end

        sleep 0.1 while !running?

        thread
    end

    # Waits for the Reactor to stop {#running?}.
    #
    # @raise    (see #fail_if_not_running)
    def wait
        fail_if_not_running

        @done_signal.pop
        true
    end

    # Starts the {#run Reactor loop}, blocks the current {#thread} while the
    # given `block` executes and then {#stop}s it.
    #
    # @param    [Block] block
    #   Block to call.
    #
    # @raise    (see #fail_if_running)
    def run_block( &block )
        fail ArgumentError, 'Missing block.' if !block_given?
        fail_if_running

        run do
            block.call
            next_tick { stop }
        end
    end

    # @param    [Block] block
    #   Passes exceptions raised in the Reactor {#thread} to a
    #   {Tasks::Persistent task}.
    #
    # @raise    (see #fail_if_not_running)
    def on_error( &block )
        fail_if_not_running
        @error_handlers << Tasks::Persistent.new( &block )
        nil
    end

    # @param    [Block] block
    #   Schedules a {Tasks::Persistent task} to be run at each tick.
    #
    # @raise    (see #fail_if_not_running)
    def on_tick( &block )
        fail_if_not_running
        @tasks << Tasks::Persistent.new( &block )
        nil
    end

    # @param    [Block] block
    #   Schedules a task to be run as soon as possible, either immediately if
    #   the caller is {#in_same_thread? in the same thread}, or at the
    #   {#next_tick} otherwise.
    #
    # @raise    (see #fail_if_not_running)
    def schedule( &block )
        fail_if_not_running

        if in_same_thread?
            block.call
        else
            next_tick(&block)
        end

        nil
    end

    # @param    [Block] block
    #   Schedules a {Tasks::OneOff task} to be run at {#stop shutdown}.
    #
    # @raise    (see #fail_if_not_running)
    def on_shutdown( &block )
        fail_if_not_running
        @shutdown_tasks << Tasks::OneOff.new( &block )
        nil
    end

    # @param    [Block] block
    #   Schedules a {Tasks::OneOff task} to be run at the next tick.
    #
    # @raise    (see #fail_if_not_running)
    def next_tick( &block )
        fail_if_not_running
        @tasks << Tasks::OneOff.new( &block )
        nil
    end

    # @note Time accuracy cannot be guaranteed.
    #
    # @param    [Float] interval
    #   Time in seconds.
    # @param    [Block] block
    #   Schedules a {Tasks::Periodic task} to be run at every `interval` seconds.
    #
    # @raise    (see #fail_if_not_running)
    def at_interval( interval, &block )
        fail_if_not_running
        @tasks << Tasks::Periodic.new( interval, &block )
        nil
    end

    # @note Time accuracy cannot be guaranteed.
    #
    # @param    [Float] time
    #   Time in seconds.
    # @param    [Block] block
    #   Schedules a {Tasks::Delayed task} to be run in `time` seconds.
    #
    # @raise    (see #fail_if_not_running)
    def delay( time, &block )
        fail_if_not_running
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
    #
    # @raise    (see #fail_if_not_running)
    def in_same_thread?
        fail_if_not_running
        Thread.current == thread
    end

    # @note Will call {Connection::Callbacks#on_attach}.
    #
    # {Connection#attach Attaches} a connection to the {Reactor} loop.
    #
    # @param    [Connection]    connection
    #
    # @raise    (see #fail_if_not_running)
    def attach( connection )
        return if attached? connection

        schedule do
            connection.reactor = self
            @connections[connection.to_io] = connection
            connection.on_attach
        end
    end

    # @note Will call {Connection::Callbacks#on_detach}.
    #
    # {Connection#detach Detaches} a connection from the {Reactor} loop.
    #
    # @param    [Connection]    connection
    #
    # @raise    (see #fail_if_not_running)
    def detach( connection )
        return if !attached?( connection )

        schedule do
            connection.on_detach
            @connections.delete connection.to_io
            connection.reactor = nil
        end
    end

    # @return   [Bool]
    #   `true` if the connection is attached, `false` otherwise.
    def attached?( connection )
        @connections.include? connection.to_io
    end

    private

    # @raise    [Error::NotRunning]
    #   If the Reactor is not {#running?}.
    def fail_if_not_running
        fail Error::NotRunning, 'Reactor is not running.' if !running?
    end

    # @raise    [Error::NotRunning]
    #   If the Reactor is already {#running?}.
    def fail_if_running
        fail Error::AlreadyRunning, 'Reactor is already running.' if running?
    end

    # @raise    [Error::UNIXSocketsNotSupported]
    #   If trying to use UNIX-domain sockets on a host OS that does not
    #   support them.
    def fail_if_non_unix
        return if self.class.supports_unix_sockets?

        fail Error::UNIXSocketsNotSupported,
             'The host OS does not support UNIX-domain sockets.'
    end

    def determine_connection_options( *args )
        options = {}

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
        fail_if_non_unix

        UNIXSocket.new( unix_socket )
    end

    # @return   [Socket]
    #   Connected socket.
    def connect_tcp
        socket = Socket.new(
            Socket::Constants::AF_INET,
            Socket::Constants::SOCK_STREAM,
            Socket::Constants::IPPROTO_IP
        )
        socket.do_not_reverse_lookup = true
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
        @connections.values.each(&:close)
    end

    def process_connections
        if @connections.empty?
            sleep @max_tick_interval
            return
        end

        # Get connections with available events - :read, :write, :error.
        selected = select_connections

        # Close connections that have errors.
        selected.delete(:error)&.each(&:close)

        # Call the corresponding event on the connections.
        selected.each { |event, connections| connections.each(&"_#{event}".to_sym) }
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
        r = []
        w = []
        e = []

        @connections.values.each do |connection|

            # Required for OSX as it connects immediately and then #select returns
            # nothing as there's no activity, given that, OpenSSL doesn't get a chance
            # to do its handshake so explicitly connect pending sockets, bypassing #select.
            connection._connect if !connection.connected?

            socket = connection.socket

            e << socket

            if connection.listener? || connection.connected?
                r << socket
            end

            if connection.connected? && connection.has_outgoing_data?
                w << socket
            end
        end

        selected_sockets =
            begin
                Connection::Error.translate do
                    select( r, w, e, @select_timeout )
                end
            rescue Connection::Error => e
                nil
            end

        selected_sockets ||= [[],[],[]]

        # SSL sockets maintain their own buffer whose state can't be checked by
        # Kernel.select, leading to cases where the SSL buffer isn't empty,
        # even though Kernel.select says that there's nothing to read.
        #
        # So force a read for SSL sockets to cover all our bases.
        #
        # This is apparent especially on JRuby.
        if r.size != selected_sockets[0].size
            (r - selected_sockets[0]).each do |socket|
                next if !socket.is_a?( OpenSSL::SSL::SSLSocket )
                selected_sockets[0] << socket
            end
        end

        if selected_sockets[0].empty? && selected_sockets[1].empty? &&
            selected_sockets[2].empty?
            return {}
        end

        {
            # Since these will be processed in order, it's better have the write
            # ones first to flush the buffers ASAP.
            write:   connections_from_sockets( selected_sockets[1] ),
            read:    connections_from_sockets( selected_sockets[0] ),
            error:   connections_from_sockets( selected_sockets[2] )
        }
    end

    def connections_from_sockets( sockets )
        sockets.map { |s| @connections[s.to_io] }
    end

end

end
