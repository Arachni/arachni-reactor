require 'reactor'

# Global, shared Reactor.
reator = Arachni::Reactor.global

host = '127.0.0.1'
port = 7331

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

reator.run do

    reator.listen host, port , EchoServer, '(world, world, world...)'
    reator.connect host, port, EchoClient, 'Hello world!'

end
