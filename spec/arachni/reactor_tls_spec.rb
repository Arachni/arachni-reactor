require 'spec_helper'

describe 'Arachni::Reactor with TLS' do
    before :all do
        @host, @port = Servers.start( :echo_tls )

        _, port = Servers.start( :echo_unix_tls )
        @unix_socket = port_to_socket( port )
    end

    let(:echo_client_handler) { EchoClientTLS }
    let(:echo_server_handler) { EchoServerTLS }

    let(:tcp_writer) { method(:tcp_ssl_write) }
    let(:unix_writer) { method(:unix_ssl_write) }

    it_should_behave_like 'Arachni::Reactor'
end
