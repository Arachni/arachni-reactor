require 'spec_helper'

require 'spec_helper'

class Handler < Arachni::Reactor::Connection
    attr_reader :received_data
    attr_reader :error

    def initialize( options = {} )
        @options = options
    end

    def on_close( error )
        @error = error

        if @options[:on_error]
            @options[:on_error].call error
        end

        @reactor.stop
    end

    def on_read( data )
        (@received_data ||= '' ) << data

        return if !@options[:on_read]
        @options[:on_read].call data
    end

end

describe Arachni::Reactor::Connection do
    before :all do
        @host, @port = Servers.start( :echo )

        if Arachni::Reactor.supports_unix_sockets?
            _, port = Servers.start( :echo_unix )
            @unix_socket = port_to_socket( port )
        end
    end

    let(:unix_socket) { unix_connect( @unix_socket ) }

    let(:echo_client) { tcp_connect( @host, @port ) }
    let(:echo_client_handler) { EchoClient.new }

    let(:peer_client_socket) { tcp_connect( host, port ) }
    let(:peer_server_socket) { tcp_server( host, port ) }

    let(:client_socket) { tcp_connect( host, port ) }
    let(:server_socket) { tcp_server( host, port ) }

    let(:connection) { Handler.new }
    let(:server_handler) { proc { Handler.new } }

    it_should_behave_like 'Arachni::Reactor::Connection'
end
