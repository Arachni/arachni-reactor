server = tcp_ssl_server( $options[:host], $options[:port] )

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
                next if (line = socket.gets).to_s.empty?
                socket.write( line )
            end
        rescue EOFError, Errno::EPIPE
            socket.close
        end
    end
end
