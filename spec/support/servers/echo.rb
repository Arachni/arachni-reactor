server = tcp_server( $options[:host], $options[:port] )

loop do
    Thread.new server.accept do |socket|
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
