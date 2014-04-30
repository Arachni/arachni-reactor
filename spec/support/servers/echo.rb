server = tcp_server( $options[:host], $options[:port] )

loop do
    Thread.new server.accept do |socket|
        begin
            loop do
                next if !(line = socket.gets)
                socket.write( line )
            end
        rescue EOFError, Errno::EPIPE
            socket.close
        end
    end
end
