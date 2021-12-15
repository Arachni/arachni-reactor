server = unix_ssl_server( port_to_socket( $options[:port] ) )

loop do
    socket = nil
    begin
        socket = server.accept
    rescue => e
        # ap e
        next
    end

    Thread.new do
        begin
            loop do
                next if (data = socket.gets).to_s.empty?
                socket.write( data )
            end
        rescue EOFError, Errno::EPIPE, Errno::ECONNRESET
            socket.close
        end
    end
end
