require 'spec_helper'

describe Arachni::Reactor do
    before :all do
        @host, @port = Servers.start( :echo )

        _, port = Servers.start( :echo_unix )
        @unix_socket = port_to_socket( port )
    end

    let(:echo_client_handler) { EchoClient }
    let(:echo_server_handler) { EchoServer }

    let(:tcp_writer) { method(:tcp_write) }
    let(:unix_writer) { method(:unix_write) }

    it_should_behave_like 'Arachni::Reactor'
end
