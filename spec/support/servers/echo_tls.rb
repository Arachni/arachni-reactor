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
                next if (data = socket.gets).to_s.empty?
                socket.write( data )
            end
        rescue EOFError, Errno::EPIPE, Errno::ECONNRESET
            socket.close
        end
    end
end
