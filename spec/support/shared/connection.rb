shared_examples_for 'Arachni::Reactor::Connection' do
    after(:each) do
        next if !@reactor

        if @reactor.running?
            @reactor.stop
        end

        @reactor = nil
    end

    let(:host){ '127.0.0.1' }
    let(:port){ Servers.available_port }
    let(:reactor) { @reactor = Arachni::Reactor.new }
    let(:block_size) { Arachni::Reactor::Connection::BLOCK_SIZE }
    let(:data) { 'b' * 5 * block_size }
    let(:configured) do
        connection.reactor = reactor
        connection.configure(
            host:           host,
            port:           port,
            socket:         socket,
            role:           role,
            server_handler: server_handler
        )

        if role == :client
            while !connection.connected?
                begin
                    IO.select( [connection.socket], [connection.socket], nil, 0.1 )
                rescue => e
                    ap e
                    break
                end

                connection._connect
            end
        end

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

        # it 'calls #on_connect' do
        #     peer_server_socket
        #     connection.should receive(:on_connect)
        #     connection.reactor = reactor
        #     connection.configure socket: socket, role: role
        # end
    end

    describe '#unix?' do
        context 'when using an IP socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { client_socket }

            it 'returns false' do
                peer_server_socket
                configured
                configured.should_not be_unix
            end
        end

        context 'when using UNIX-domain socket',
                if: Arachni::Reactor.supports_unix_sockets? do

            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { unix_socket }

            it 'returns true' do
                peer_server_socket
                configured
                configured.should be_unix
            end
        end
    end

    describe '#inet?' do
        context 'when using an IP socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { client_socket }

            it 'returns false' do
                peer_server_socket
                configured
                configured.should be_inet
            end
        end

        context 'when using UNIX-domain socket',
                if: Arachni::Reactor.supports_unix_sockets? do

            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { unix_socket }

            it 'returns false' do
                peer_server_socket
                configured
                configured.should_not be_inet
            end
        end
    end

    describe '#to_io' do
        context 'when the connection is a server listener' do
            let(:role) { :server }

            context 'when using an IP socket' do
                let(:socket) { server_socket }

                it 'returns TCPServer' do
                    reactor.run_in_thread
                    configured

                    configured.to_io.should be_kind_of TCPServer
                end
            end

            context 'when using UNIX-domain socket',
                    if: Arachni::Reactor.supports_unix_sockets? do

                let(:connection) { echo_client_handler }
                let(:socket) { unix_server_socket }

                it 'returns UNIXServer' do
                    peer_server_socket
                    configured.to_io.should be_instance_of UNIXServer
                end
            end
        end

        context 'when the connection is a server handler' do
            let(:role) { :server }

            context 'when using an IP socket' do
                let(:socket) { server_socket }

                it 'returns TCPSocket' do
                    reactor.run_in_thread
                    configured

                    Thread.new do
                        client = peer_client_socket
                        client.write( data )
                    end

                    IO.select [configured.socket]
                    configured.accept.to_io.should be_kind_of TCPSocket
                end
            end
        end

        context 'when the connection is a client' do
            context 'when using an IP socket' do
                let(:role) { :client }
                let(:socket) { client_socket }

                it 'returns TCPSocket' do
                    peer_server_socket
                    configured.to_io.should be_instance_of Socket
                end
            end

            context 'when using UNIX-domain socket',
                    if: Arachni::Reactor.supports_unix_sockets? do

                let(:role) { :client }
                let(:socket) { unix_socket }

                it 'returns UNIXSocket' do
                    peer_server_socket
                    configured.to_io.should be_instance_of UNIXSocket
                end
            end
        end
    end

    describe '#listener?' do
        context 'when the connection is a server listener' do
            let(:role) { :server }

            context 'when using an IP socket' do
                let(:socket) { server_socket }

                it 'returns true' do
                    reactor.run_in_thread
                    configured

                    configured.should be_listener
                end
            end

            context 'when using UNIX-domain socket',
                    if: Arachni::Reactor.supports_unix_sockets? do

                let(:connection) { echo_client_handler }
                let(:socket) { unix_server_socket }

                it 'returns true' do
                    peer_server_socket
                    configured.should be_listener
                end
            end
        end

        context 'when the connection is a server handler' do
            let(:role) { :server }

            context 'when using an IP socket' do
                let(:socket) { server_socket }

                it 'returns false' do
                    reactor.run_in_thread
                    configured

                    Thread.new do
                        client = peer_client_socket
                        client.write( data )
                    end

                    IO.select [configured.socket]
                    configured.accept.should_not be_listener
                end
            end
        end

        context 'when the connection is a client' do
            context 'when using an IP socket' do
                let(:role) { :client }
                let(:socket) { client_socket }

                it 'returns false' do
                    peer_server_socket
                    configured.should_not be_listener
                end
            end

            context 'when using UNIX-domain socket',
                    if: Arachni::Reactor.supports_unix_sockets? do

                let(:role) { :client }
                let(:socket) { unix_socket }

                it 'returns false' do
                    peer_server_socket
                    configured.should_not be_listener
                end
            end
        end
    end

    describe '#attach' do
        let(:socket) { client_socket }
        let(:role) { :client }

        it 'attaches the connection to a Reactor' do
            peer_server_socket
            configured

            reactor.run_in_thread

            connection.attach( reactor ).should be_truthy
            sleep 1

            reactor.attached?( configured ).should be_truthy
        end

        it 'calls #on_attach' do
            peer_server_socket
            configured

            reactor.run_in_thread

            configured.should receive(:on_attach)
            connection.attach reactor

            sleep 1
        end

        context 'when the connection is already attached' do
            context 'to the same Reactor' do
                it 'does nothing' do
                    peer_server_socket
                    configured

                    reactor.run_in_thread

                    connection.attach reactor
                    sleep 0.1 while connection.detached?

                    connection.attach( reactor ).should be_falsey
                end
            end

            context 'to a different Reactor' do
                it 'detaches it first' do
                    peer_server_socket
                    configured

                    reactor.run_in_thread

                    connection.attach reactor
                    sleep 0.1 while connection.detached?

                    r = Arachni::Reactor.new
                    r.run_in_thread

                    configured.should receive(:on_detach)
                    connection.attach( r ).should be_truthy

                    sleep 2

                    r.attached?( configured ).should be_truthy
                end
            end
        end
    end

    describe '#detach' do
        let(:socket) { client_socket }
        let(:role) { :client }

        it 'detaches the connection from the reactor' do
            peer_server_socket
            configured

            reactor.run_in_thread

            connection.attach reactor
            sleep 0.1 while !connection.attached?

            connection.detach
            sleep 0.1 while connection.attached?

            reactor.attached?( configured ).should be_falsey
        end

        it 'calls #on_detach' do
            peer_server_socket
            configured

            reactor.run_in_thread

            connection.attach reactor
            sleep 0.1 while !connection.attached?

            configured.should receive(:on_detach)
            connection.detach

            sleep 0.1 while connection.attached?
        end
    end

    describe '#write' do
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { client_socket }

        it 'appends the given data to the send-buffer' do
            peer_server_socket
            reactor.run_in_thread

            configured

            all_read = false
            received = ''

            t = Thread.new do
                sleep 0.1 while !accepted
                received << accepted.read( data.size ) while received.size != data.size
                all_read = true
            end

            configured.write data

            # Wait for the reactor to update the buffer.
            sleep 0.1 while !configured.has_outgoing_data?

            while !all_read
                IO.select( nil, [configured.socket], nil, 1 ) rescue IOError
                next if configured._write != 0

                IO.select( [configured.socket], nil, nil, 1 ) rescue IOError
            end

            t.join

            received.should == data
        end
    end

    describe '#accept' do
        let(:socket) { server_socket }
        let(:role) { :server }
        let(:data) { "data\n" }

        it 'accepts a new client connection' do
            reactor.run_in_thread
            configured

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

    describe '#_read' do
        context 'when the connection is a socket' do
            let(:connection) { echo_client_handler }
            let(:role) { :client }
            let(:socket) { client_socket }

            it "reads a maximum of #{Arachni::Reactor::Connection::BLOCK_SIZE} bytes at a time" do
                peer_server_socket
                configured

                Thread.new do
                    sleep 0.1 while !accepted
                    accepted.write data
                    accepted.flush
                end

                while configured.received_data.to_s.size != data.size
                    pre = configured.received_data.to_s.size
                    configured._read
                    (configured.received_data.to_s.size - pre).should <= block_size
                end

                configured.received_data.size.should == data.size
            end

            it 'passes the data to #on_read' do
                peer_server_socket
                configured

                data = "test\n"

                Thread.new do
                    sleep 0.1 while !accepted
                    accepted.write data
                    accepted.flush
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

    describe '#_write' do
        before :each do
            reactor.run_in_thread
        end

        let(:port) { @port }
        let(:host) { @host }
        let(:connection) { echo_client_handler }
        let(:role) { :client }
        let(:socket) { echo_client }

        it "consumes the write-buffer a maximum of #{Arachni::Reactor::Connection::BLOCK_SIZE} bytes at a time" do
            configured.write data
            sleep 0.1 while !configured.has_outgoing_data?

            writes = 0
            while configured.has_outgoing_data?
                IO.select( nil, [configured.socket] )
                if (written = configured._write) == 0
                    IO.select( [configured.socket], nil, nil, 1 )
                    next
                end

                written.should <= block_size
                writes += 1
            end

            writes.should > 1
        end

        it 'calls #on_write' do
            configured.write data
            sleep 0.1 while !configured.has_outgoing_data?

            writes = 0
            while configured.has_outgoing_data?
                IO.select( nil, [configured.socket] )

                next if configured._write == 0

                writes += 1
            end

            configured.on_write_count.should >= writes
        end

        context 'when the buffer is entirely consumed' do
            it 'calls #on_flush' do
                configured.write data
                sleep 0.1 while !configured.has_outgoing_data?

                while configured.has_outgoing_data?
                    IO.select( nil, [configured.socket] )

                    if configured._write == 0
                        IO.select( [configured.socket] )
                        next
                    end
                end

                configured.called_on_flush.should be_truthy
            end
        end
    end

    describe '#has_outgoing_data?' do
        let(:port) { @port }
        let(:host) { @host }

        let(:role) { :client }
        let(:socket) { echo_client }

        context 'when the send-buffer is not empty' do
            it 'returns true' do
                reactor.run_in_thread

                configured.write 'test'
                sleep 0.1 while !configured.has_outgoing_data?

                configured.has_outgoing_data?.should be_truthy
            end
        end

        context 'when the send-buffer is empty' do
            it 'returns false' do
                configured.has_outgoing_data?.should be_falsey
            end
        end
    end

    describe '#closed?' do
        let(:port) { @port }
        let(:host) { @host }

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
        let(:port) { @port }
        let(:host) { @host }

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
        let(:port) { @port }
        let(:host) { @host }

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
