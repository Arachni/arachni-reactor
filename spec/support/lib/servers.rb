require 'singleton'
require 'net/http'

class Servers
    include Singleton

    RUNNER = "#{support_lib_path}/servers/runner.rb"

    attr_reader :lib

    def initialize
        @lib     = File.expand_path( File.dirname(__FILE__) + '/../servers' )
        @servers = {}

        Dir.glob(File.join(@lib + '/**', '*.rb')) do |path|
            @servers[normalize_name( File.basename(path, '.rb') )] = {
                port: available_port,
                path: path
            }
        end
    end

    def start( name )
        server_info = data_for( name )

        return [host_for(name), port_for(name)] if server_info[:pid] && up?( name )

        server_info[:pid] = Process.spawn(
            RbConfig.ruby, RUNNER, server_info[:path], '-p', server_info[:port].to_s,
            '-o', host_for( name )
        )

        Process.detach server_info[:pid]

        sleep 0.1 while !up?( name )

        [host_for(name), port_for(name)]
    end

    def address_for( name )
        "#{host_for( name )}:#{port_for( name )}"
    end

    def host_for( name )
        '127.0.0.1'
    end

    def port_for( name )
        data_for( name )[:port]
    end

    def up?( name )
        if name.to_s.include? 'unix'
            return File.exist?( port_to_socket( port_for( name ) ) )
        end

        socket   = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
        sockaddr = Socket.sockaddr_in( port_for( name ), host_for( name ) )

        begin
            socket.connect( sockaddr )
        rescue Errno::ECONNREFUSED, Errno::EADDRINUSE
            return false
        end

        socket.close

        true
    end

    def data_for( name )
        @servers[normalize_name( name )]
    end

    def kill( name )
        server_info = data_for( name )
        return if !server_info[:pid]

        begin
            Process.kill( 'KILL', server_info[:pid] ) while sleep 0.1
        rescue Errno::ESRCH
            server_info.delete(:pid)

            socket = port_to_socket( server_info[:port] )
            if File.exist?( socket )
                File.delete socket
            end

            return true
        end
    end

    def killall
        @servers.keys.each { |n| kill n }
    end

    def available_port
        loop do
            port = 5555 + rand( 9999 )

            begin
                socket = ::Socket.new( :INET, :STREAM, 0 )
                socket.bind( ::Socket.sockaddr_in( port, '127.0.0.1' ) )
                socket.close

                return port if !File.exist?( port_to_socket( port ) )
            rescue Errno::EADDRINUSE
            end
        end
    end

    def normalize_name( name )
        name.to_s.to_sym
    end

    def self.method_missing( sym, *args, &block )
        if instance.respond_to?( sym )
            instance.send( sym, *args, &block )
        elsif super( sym, *args, &block )
        end
    end

    def self.respond_to?( m )
        super( m ) || instance.respond_to?( m )
    end

    private

    def set_data_for( name, data )
        @servers[normalize_name( name )] = data
    end

end
