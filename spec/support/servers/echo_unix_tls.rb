server = unix_ssl_server( port_to_socket( $options[:port] ) )

loop do
    socket = server.accept rescue next

    Thread.new do
        begin
            loop do
                next if (line = socket.gets).empty?
                socket.write( line )
            end
        rescue EOFError, Errno::EPIPE
            socket.close
        end
    end
end
