server = unix_server( port_to_socket( $options[:port] ) )

loop do
    Thread.new server.accept do |socket|
        begin
            loop do
                next if (data = socket.readpartial(99999)).to_s.empty?
                socket.write( data )
            end
        rescue EOFError, Errno::EPIPE
            socket.close
        end
    end
end
