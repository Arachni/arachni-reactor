require 'spec_helper'

class TLSHandler < Arachni::Reactor::Connection
    include TLS

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

    def on_connect
        start_tls @options
    end

end

describe Arachni::Reactor::Connection::TLS do
    before :all do
        @host, @port = Servers.start( :echo_tls )

        _, port = Servers.start( :echo_unix )
        @unix_socket = port_to_socket( port )
    end

    let(:unix_socket) { unix_connect( @unix_socket ) }

    let(:echo_client) { tcp_connect( @host, @port ) }
    let(:echo_client_handler) { EchoClientTLS.new }

    let(:peer_client_socket) { tcp_ssl_connect( host, port ) }
    let(:peer_server_socket) { tcp_ssl_server( host, port ) }

    let(:client_socket) { tcp_connect( host, port ) }
    let(:server_socket) { tcp_server( host, port ) }

    let(:connection) { TLSHandler.new }
    let(:server_handler) { proc { TLSHandler.new } }
    let(:reactor) { Arachni::Reactor.new }

    let(:client_valid_ssl_options) do
        {
            ca:          pems_path + '/cacert.pem',
            private_key: pems_path + '/client/key.pem',
            certificate: pems_path + '/client/cert.pem'
        }
    end
    let(:client_invalid_ssl_options) do
        {
            ca:          pems_path + '/cacert.pem',
            private_key: pems_path + '/client/foo-key.pem',
            certificate: pems_path + '/client/foo-cert.pem'
        }
    end

    let(:server_valid_ssl_options) do
        {
            ca:          pems_path + '/cacert.pem',
            private_key: pems_path + '/server/key.pem',
            certificate: pems_path + '/server/cert.pem'
        }
    end

    it_should_behave_like 'Arachni::Reactor::Connection'

    context '#start_tls' do
        let(:host) { 'localhost' }
        let(:port) { Servers.available_port }
        let(:data) { "stuff\n" }

        context 'when listening for a client' do
            let(:client) do
                tcp_ssl_connect( host, port, client_ssl_options )
            end

            context 'without requiring SSL authentication' do
                let(:server_ssl_options) { {} }

                context 'and no options have been provided' do
                    let(:client_ssl_options) { {} }

                    it 'connects successfully' do
                        received_data = nil
                        options = server_ssl_options.merge(
                            on_read: proc do |received|
                                received_data = received
                            end
                        )

                        reactor.run_in_thread

                        reactor.listen( host, port, TLSHandler, options )

                        client.write data
                        reactor.stop
                        reactor.wait rescue Arachni::Reactor::Error::NotRunning

                        received_data.should == data
                    end
                end

                context 'and options have been provided' do
                    let(:client_ssl_options) { client_valid_ssl_options }

                    it "passes #{Arachni::Reactor::Connection::Error::SSL} to #on_error" do
                        error = nil

                        options = server_ssl_options.merge(
                            on_error: proc do |e|
                                error ||= e
                            end
                        )

                        reactor.run_in_thread

                        reactor.listen( host, port, TLSHandler, options )

                        expect { client }.to raise_error OpenSSL::SSL::SSLError

                        reactor.wait rescue Arachni::Reactor::Error::NotRunning

                        error.should be_kind_of Arachni::Reactor::Connection::Error::SSL
                    end
                end
            end

            context 'while requiring SSL authentication' do
                let(:server_ssl_options) { server_valid_ssl_options }

                context 'and options have been provided' do
                    context 'and are valid' do
                        let(:client_ssl_options) { client_valid_ssl_options }

                        it 'connects successfully' do
                            received_data = nil
                            options = server_ssl_options.merge(
                                on_read: proc do |received|
                                    received_data = received
                                end
                            )

                            reactor.run_in_thread

                            reactor.listen( host, port, TLSHandler, options )

                            client.write data

                            sleep 0.1 while !received_data
                            received_data.should == data
                        end
                    end

                    context 'and are invalid' do
                        let(:client_ssl_options) { client_invalid_ssl_options }

                        it "passes #{Arachni::Reactor::Connection::Error::SSL} to #on_error" do
                            error = nil

                            options = server_ssl_options.merge(
                                on_error: proc do |e|
                                    error ||= e
                                end
                            )

                            reactor.run_in_thread
                            reactor.listen( host, port, TLSHandler, options )

                            expect { client }.to raise_error OpenSSL::SSL::SSLError

                            reactor.wait rescue Arachni::Reactor::Error::NotRunning

                            error.should be_kind_of Arachni::Reactor::Connection::Error::SSL
                        end
                    end
                end

                context 'and no options have been provided' do
                    let(:client_ssl_options) { {} }

                    it "passes #{Arachni::Reactor::Connection::Error::SSL} to #on_error" do
                        error = nil

                        options = server_ssl_options.merge(
                            on_error: proc do |e|
                                error ||= e
                            end
                        )

                        reactor.run_in_thread

                        reactor.listen( host, port, TLSHandler, options )

                        expect { client }.to raise_error OpenSSL::SSL::SSLError

                        reactor.wait rescue Arachni::Reactor::Error::NotRunning

                        error.should be_kind_of Arachni::Reactor::Connection::Error::SSL
                    end
                end
            end
        end

        context 'when connecting to a server' do
            let(:server) do
                tcp_ssl_server( host, port, server_ssl_options )
            end

            before :each do
                server
            end

            context 'that does not require SSL authentication' do
                let(:server_ssl_options) { {} }

                context 'and no options have been provided' do
                    it 'connects successfully' do
                        received = nil
                        Thread.new do
                            s = server.accept
                            received = s.gets

                            reactor.stop
                        end

                        reactor.run do
                            connection = reactor.connect( host, port, TLSHandler )
                            connection.send_data data
                        end

                        received.should == data
                    end
                end
            end

            context 'that requires SSL authentication' do
                let(:server_ssl_options) { server_valid_ssl_options }

                context 'and no options have been provided' do
                    it "passes #{Arachni::Reactor::Connection::Error::SSL} to #on_error" do
                        Thread.new do
                            server.accept
                        end

                        connection = nil
                        reactor.run do
                            connection = reactor.connect( host, port, TLSHandler )
                        end

                        connection.error.should be_kind_of Arachni::Reactor::Connection::Error::SSL
                    end
                end

                context 'and options have been provided' do
                    context 'and are valid' do
                        it 'connects successfully' do
                            received = nil
                            t = Thread.new do
                                s = server.accept
                                received = s.gets
                                reactor.stop
                            end

                            reactor.run do
                                connection = reactor.connect( host, port, TLSHandler, client_valid_ssl_options )
                                connection.send_data data
                            end

                            received.should == data
                        end
                    end

                    context 'and are invalid' do
                        it "passes #{Arachni::Reactor::Connection::Error::SSL} to #on_error" do
                            Thread.new do
                                server.accept
                            end

                            connection = nil
                            reactor.run do
                                connection = reactor.connect( host, port, TLSHandler, client_invalid_ssl_options )
                            end

                            connection.error.should be_kind_of Arachni::Reactor::Connection::Error::SSL
                        end
                    end
                end
            end
        end
    end
end
