require 'spec_helper'

describe Arachni::Reactor::Connection do
    before :all do
        @host, @port = Servers.start( :echo )

        _, port = Servers.start( :echo_unix )
        @unix_socket = port_to_socket( port )
    end

    let(:unix_socket) { unix_connect( @unix_socket ) }

    let(:echo_client) { tcp_connect( @host, @port ) }
    let(:echo_client_handler) { EchoClient.new }

    let(:peer_client_socket) { tcp_connect( host, port ) }
    let(:peer_server_socket) { tcp_server( host, port ) }

    let(:client_socket) { tcp_connect( host, port ) }
    let(:server_socket) { tcp_server( host, port ) }

    let(:connection) { described_class.new }
    let(:server_handler) { proc { described_class.new } }

    it_should_behave_like 'Arachni::Reactor::Connection'
end
