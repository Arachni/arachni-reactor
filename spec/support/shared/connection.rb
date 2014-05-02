shared_examples_for 'Arachni::Reactor::Connection' do
    after(:each) do
        next if !@reactor

        if @reactor.running?
            @reactor.stop
        end

        @reactor = nil
    end

    let(:host){ 'localhost' }
    let(:port){ Servers.available_port }
    let(:reactor) { @reactor = Arachni::Reactor.new }
    let(:block_size) { Arachni::Reactor::Connection::BLOCK_SIZE }
    let(:data) { 'b' * 5 * block_size }
    let(:configured) do
        connection.reactor = reactor
        connection.configure socket, role, server_handler
        connection
    end

    describe '#configure' do
        let(:socket) { client_socket }
        let(:role) { :client }

        it 'sets #socket' do
            peer_server_socket
            configured.socket.to_io.should == socket
        end

        it 'sets #role' do
            peer_server_socket
            configured.role.should == :client
        end

        it 'attaches it to the reactor' do
            # Just to initialize it.
            peer_server_socket

            reactor.run_block do
                reactor.attach configured

                c_socket, c_connection = reactor.connections.first.to_a

                c_socket.to_io.should == socket
                c_connection.should == connection
            end
        end

        it 'calls #on_connect' do
            peer_server_socket
            connection.should receive(:on_connect)
            connection.reactor = reactor
            connection.configure socket, role
        end
    end

    describe '#peer_address_info' do
        context 'when using an IP socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { client_socket }

            it 'returns IP address information' do
                s = peer_server_socket
                configured

                Thread.new do
                    s = s.accept
                end

                IO.select( nil, [configured.socket] )

                info = {}
                info[:protocol], info[:port], info[:hostname], info[:ip_address] = s.to_io.addr
                configured.peer_address_info.should == info

                info = {}
                info[:protocol], info[:port], info[:hostname], info[:ip_address] = s.to_io.addr(false)
                configured.peer_address_info(false).should == info

                info = {}
                info[:protocol], info[:port], info[:hostname], info[:ip_address] = s.to_io.addr(true)
                configured.peer_address_info(true).should == info
            end
        end

        context 'when using UNIX-domain socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { unix_socket }

            it 'returns socket information' do
                configured

                IO.select( nil, [configured.socket] )

                info = {}
                info[:protocol], info[:path] = 'AF_UNIX', socket.path
                configured.peer_address_info.should == info
            end
        end
    end

    describe '#peer_hostname' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { client_socket }

        it 'returns the peer hostname' do
            s = peer_server_socket
            configured

            Thread.new do
                s = s.accept
            end

            IO.select( nil, [configured.socket] )

            configured.peer_hostname.should == s.to_io.addr(true)[2]
            configured.peer_hostname.should == 'localhost'
        end
    end

    describe '#peer_ip_address' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { client_socket }

        it 'returns the peer IP address' do
            s = peer_server_socket
            configured

            Thread.new do
                s = s.accept
            end

            IO.select( nil, [configured.socket] )

            configured.peer_ip_address.should == s.to_io.addr[3]
            configured.peer_ip_address.should == '127.0.0.1'
        end
    end

    describe '#peer_port' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { client_socket }

        it 'returns the peer IP address' do
            s = peer_server_socket
            configured

            Thread.new do
                s = s.accept
            end

            IO.select( nil, [configured.socket] )

            configured.peer_port.should == s.to_io.addr[1]
        end
    end

    describe '#on_attach' do
        let(:socket) { client_socket }
        let(:role) { :client }

        it 'is called when the connection gets attached to a Reactor' do
            peer_server_socket
            configured

            reactor.run_in_thread

            configured.should receive(:on_attach)
            reactor.attach connection

            sleep 1
        end
    end

    describe '#on_detach' do
        let(:socket) { client_socket }
        let(:role) { :client }

        it 'is called when the connection gets detached to a Reactor' do
            peer_server_socket
            configured

            reactor.run_in_thread

            configured.should receive(:on_detach)
            reactor.detach connection

            sleep 1
        end
    end

    describe '#write' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { client_socket }

        it 'appends the given data to the send-buffer' do
            s = peer_server_socket
            configured

            t = Thread.new do
                s = s.accept
            end

            configured.write data
            while configured.has_outgoing_data?
                IO.select( nil, [configured.socket] )
                next if configured._write != 0
                IO.select( [configured.socket] )
            end

            t.join

            s.read(data.size).should == data
        end
    end

    describe '#accept' do
        let(:socket) { server_socket }
        let(:role) { :server }
        let(:data) { "data\n" }

        it 'accepts a new client connection' do
            configured
            reactor.run_in_thread

            client = nil

            Thread.new do
                client = peer_client_socket
                client.write( data )
            end

            IO.select [configured.socket]
            server = configured.accept

            server.should be_kind_of connection.class

            IO.select [server.socket]

            sleep 0.1 while !server.received_data
            server.received_data.should == data

            client.close
        end
    end

    describe '#read' do
        context 'when the connection is a socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { client_socket }

            it "reads a maximum of #{Arachni::Reactor::Connection::BLOCK_SIZE} bytes at a time" do
                s = peer_server_socket
                configured

                Thread.new do
                    s = s.accept
                    s.write data
                    s.flush
                end

                while configured.received_data.to_s.size != data.size
                    pre = configured.received_data.to_s.size
                    configured._read
                    (configured.received_data.to_s.size - pre).should <= block_size
                end

                configured.received_data.size.should == data.size
            end

            it 'passes the data to #on_read' do
                s = peer_server_socket
                configured

                data = "test\n"

                Thread.new do
                    s = s.accept
                    s.write data
                    s.flush
                end

                configured._read while !configured.received_data
                configured.received_data.should == data
            end
        end

        context 'when the connection is a server' do
            let(:socket) { server_socket }
            let(:role) { :server }
            let(:data) { "data\n" }

            it 'accepts a new client connection' do
                configured
                reactor.run_in_thread

                client = nil

                q = Queue.new
                Thread.new do
                    client = peer_client_socket
                    q << client.write( data )
                end

                IO.select [configured.socket]
                server = configured._read

                server.should be_kind_of connection.class

                sleep 0.1 while !server.received_data
                server.received_data.should == data

                client.close
            end
        end
    end

    describe '#write' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { echo_client }

        it "consumes the send-buffer a maximum of #{Arachni::Reactor::Connection::BLOCK_SIZE} bytes at a time" do
            configured.write data

            writes = 0
            while configured.has_outgoing_data?

                IO.select( nil, [configured.socket] )
                if (written = configured._write) == 0
                    IO.select( [configured.socket], nil, nil, 1 )
                    next
                end

                written.should == block_size
                writes += 1
            end

            writes.should > 1
        end

        it 'calls #on_write' do
            configured.write data

            writes = 0
            while configured.has_outgoing_data?

                IO.select( nil, [configured.socket] )
                if configured._write == 0
                    IO.select( [configured.socket] )
                    next
                end

                writes += 1
            end

            configured.on_write_count.should == writes
        end

        context 'when the buffer is entirely consumed' do
            it 'calls #on_flush' do
                configured.write data

                while configured.has_outgoing_data?
                    IO.select( nil, [configured.socket] )

                    if (written = configured._write) == 0
                        IO.select( [configured.socket] )
                        next
                    end

                    written.should == block_size
                end

                configured.called_on_flush.should be_true
            end
        end
    end

    describe '#has_outgoing_data?' do
        let(:role) { :client }
        let(:socket) { echo_client }

        context 'when the send-buffer is not empty' do
            it 'returns true' do
                configured.write 'test'
                configured.has_outgoing_data?.should be_true
            end
        end

        context 'when the send-buffer is empty' do
            it 'returns false' do
                configured.has_outgoing_data?.should be_false
            end
        end
    end

    describe '#closed?' do
        let(:role) { :client }
        let(:socket) { echo_client }

        context 'when the connection has been closed' do
            it 'returns true' do
                reactor.run do
                    configured.close
                end

                configured.should be_closed
            end
        end

        context 'when the send-buffer is empty' do
            it 'returns false' do
                configured.should_not be_closed
            end
        end
    end

    describe '#close_without_callback' do
        let(:role) { :client }
        let(:socket) { echo_client }

        it 'closes the #socket' do
            reactor.run_in_thread
            configured.socket.should receive(:close)
            configured.close_without_callback
        end

        it 'detaches the connection from the reactor' do
            configured

            reactor.run_block do
                reactor.attach configured
                reactor.connections.should be_any
                configured.close_without_callback
                reactor.connections.should be_empty
            end
        end

        it 'does not call #on_close' do
            reactor.run_in_thread
            configured.should_not receive(:on_close)
            configured.close_without_callback
        end
    end

    describe '#close' do
        let(:role) { :client }
        let(:socket) { echo_client }

        before(:each) { reactor.run_in_thread }

        it 'calls #close_without_callback' do
            configured.should receive(:close_without_callback)
            configured.close
        end

        it 'calls #on_close' do
            configured.should receive(:on_close)
            configured.close
        end

        context 'when a reason is given' do
            it 'is passed to #on_close' do
                configured.should receive(:on_close).with(:my_reason)
                configured.close :my_reason
            end
        end
    end
end
