require_relative '../lib/arachni/reactor'

# Global, shared Reactor.
reator = Arachni::Reactor.global

host = '127.0.0.1'
port = 9695

class EchoServer < Arachni::Reactor::Connection
    include TLS

    def initialize( append )
        @append = append
    end

    def on_connect
        start_tls
    end

    def on_read( data )
        with_echo = "#{data} #{@append}"

        puts "Server - Echoing: #{with_echo}"
        write with_echo
    end
end

class EchoClient < Arachni::Reactor::Connection
    include TLS

    def initialize( message )
        @message = message
    end

    def on_connect
        start_tls

        puts "Client - Sending: #{@message}"
        write @message
    end

    def on_read( data )
        puts "Client - Got: #{data}"
        @reactor.stop
    end
end

class EchoServerNIO
    def initialize(host, port)
        @selector = NIO::Selector.new

        puts "Listening on #{host}:#{port}"
        @server = TCPServer.new(host, port)

        monitor = @selector.register(@server, :r)
        monitor.value = proc { accept }
    end

    def run
        loop do
            @selector.select { |monitor| monitor.value.call }
        end
    end

    def accept
        socket = @server.accept
        _, port, host = socket.peeraddr
        puts "*** #{host}:#{port} connected"

        monitor = @selector.register(socket, :r)
        monitor.value = proc { read(socket) }
    end

    def read(socket)
        data = socket.read_nonblock(4096)
        socket.write_nonblock(data)
    rescue EOFError
        _, port, host = socket.peeraddr
        puts "*** #{host}:#{port} disconnected"

        @selector.deregister(socket)
        socket.close
    end
end

# Thread.new do
#     EchoServerNIO.new( host, port ).run
# end
# sleep 0.1

reator.run do

    reator.listen host, port , EchoServer, '(world, world, world...)'
    reator.connect host, port, EchoClient, 'Hello world!'


    # Thread.new do
    #     socket = TCPSocket.new( host, port)
    #     socket.puts( "Test" )
    #     socket.flush
    #     p socket.read( 1024 )
    #     socket.close
    #
    #     reactor.stop
    # end
end
