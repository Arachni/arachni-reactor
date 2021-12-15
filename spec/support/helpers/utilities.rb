require 'socket'
require 'openssl'

def port_to_socket( port )
    "/tmp/arachni-reactor-socket-#{port}"
end

def run_reactor_in_thread
    t = Thread.new do
        reactor.run
    end
    sleep 0.1
    t
end

def tcp_connect( host, port )
    TCPSocket.new( host, port )
end

def tcp_socket
    socket = Socket.new(
        Socket::Constants::AF_INET,
        Socket::Constants::SOCK_STREAM,
        Socket::Constants::IPPROTO_IP
    )
    socket.do_not_reverse_lookup = true
    socket
end

def tcp_write( host, port, data )
    s = tcp_connect( host, port )
    s.write data
    s
end

if Arachni::Reactor.supports_unix_sockets?

    def unix_connect( socket )
        UNIXSocket.new( socket )
    end

    def unix_server( socket )
        UNIXServer.new( socket )
    end

end

def unix_write( socket, data )
    s = unix_connect( socket )
    s.write data
    s
end

def tcp_server( host, port )
    TCPServer.new( host, port )
end

def tcp_ssl_socket( host, port, options = {}  )
    convert_client_to_ssl( tcp_socket, options )
end

def tcp_ssl_connect( host, port, options = {}  )
    convert_client_to_ssl( tcp_connect( host, port ), options )
end

def unix_ssl_connect( socket, options = {}  )
    convert_client_to_ssl( unix_connect( socket ), options)
end

def tcp_ssl_write( host, port, data, options = {} )
    s = tcp_ssl_connect( host, port, options )
    s.write data
    s
end

def unix_ssl_write( socket, data, options = {} )
    s = unix_ssl_connect( socket, options )
    s.write data
    s
end

def unix_ssl_server( socket, options = {} )
    convert_server_to_ssl( unix_server( socket ), options )
end

def tcp_ssl_server( host, port, options = {} )
    convert_server_to_ssl( tcp_server( host, port ), options )
end

def ssl_context( options )
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new( File.open( options[:certificate] ) )
    context.key  = OpenSSL::PKey::RSA.new( File.open( options[:private_key] ) )

    context.ca_file     = options[:ca]
    context.verify_mode =
        OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT

    context
end

def convert_server_to_ssl( server, options = {} )
    if options[:certificate] && options[:private_key]
        context = ssl_context( options )
    else
        context                 = OpenSSL::SSL::SSLContext.new
        context.key             = OpenSSL::PKey::RSA.new( 2048 )
        context.cert            = OpenSSL::X509::Certificate.new
        context.cert.subject    = OpenSSL::X509::Name.new( [['CN', 'localhost']] )
        context.cert.issuer     = context.cert.subject
        context.cert.public_key = context.key
        context.cert.not_before = Time.now
        context.cert.not_after  = Time.now + 60 * 60 * 24
        context.cert.version    = 2
        context.cert.serial     = 1

        context.cert.sign( context.key, OpenSSL::Digest::SHA256.new )
    end

    OpenSSL::SSL::SSLServer.new( server, context )
end

def convert_client_to_ssl( client, options = {} )
    if options[:certificate] && options[:private_key]
        context = ssl_context( options )
    else
        context = OpenSSL::SSL::SSLContext.new
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    s = OpenSSL::SSL::SSLSocket.new( client, context )
    s.sync_close = true
    s.connect
    s
end
