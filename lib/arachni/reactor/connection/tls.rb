=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module OpenSSL
module SSL
class SSLServer
    unless public_method_defined? :accept_nonblock
        def accept_nonblock
            sock = @svr.accept_nonblock

            begin
                ssl = OpenSSL::SSL::SSLSocket.new( sock, @ctx )
                ssl.sync_close = true
                ssl.accept if @start_immediately
                ssl
            rescue SSLError => e
                if ssl
                    ssl.close
                else
                    sock.close
                end

                raise e
            end
        end
    end
end
end
end

module Arachni
class Reactor
class Connection

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module TLS

    # Converts the {#socket} to an SSL one.
    #
    # @param    [Hash]  options
    # @option   [String]    :certificate
    #   Path to a PEM certificate.
    # @option   [String]    :private_key
    #   Path to a PEM private key.
    # @option   [String]    :ca
    #   Path to a PEM CA.
    def start_tls( options = {} )
        if @socket.is_a? OpenSSL::SSL::SSLSocket
            @ssl_context = @socket.context
            return
        end

        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

        if options[:certificate] && options[:private_key]

            @ssl_context.cert =
                OpenSSL::X509::Certificate.new( File.open( options[:certificate] ) )
            @ssl_context.key  =
                OpenSSL::PKey::RSA.new( File.open( options[:private_key] ) )

            @ssl_context.ca_file     = options[:ca]
            @ssl_context.verify_mode =
                OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT

        elsif @role == :server
            @ssl_context.key             = OpenSSL::PKey::RSA.new( 2048 )
            @ssl_context.cert            = OpenSSL::X509::Certificate.new
            @ssl_context.cert.subject    = OpenSSL::X509::Name.new( [['CN', 'localhost']] )
            @ssl_context.cert.issuer     = @ssl_context.cert.subject
            @ssl_context.cert.public_key = @ssl_context.key
            @ssl_context.cert.not_before = Time.now
            @ssl_context.cert.not_after  = Time.now + 60 * 60 * 24
            @ssl_context.cert.version    = 2
            @ssl_context.cert.serial     = 1

            @ssl_context.cert.sign( @ssl_context.key, OpenSSL::Digest::SHA1.new )
        end

        @reactor.selector.deregister( @socket )

        if @role == :server
            @socket = OpenSSL::SSL::SSLServer.new( @socket, @ssl_context )
            @socket.start_immediately = true

            monitor = @reactor.selector.register( @socket, :r )
            monitor.value = self

            @ssl_connected = true
        else
            @socket = OpenSSL::SSL::SSLSocket.new( @socket, @ssl_context )
            @socket.sync_close = true

            monitor = @reactor.selector.register( @socket, :rw )
            monitor.value = self
        end

        @socket
    end

    def connected?
        !!@ssl_connected
    end

    def _connected!
        @ssl_connected = true
    end

    # Performs an SSL handshake in addition to a plaintext connect operation.
    #
    # @private
    def _connect
        return if connected?

        Error.translate do
            @plaintext_connected ||= super
            return if !@plaintext_connected

            @socket.connect_nonblock

            _connected!
        end
    rescue Errno::EINPROGRESS, IO::WaitReadable, IO::WaitWritable
    rescue Error => e
        close e
    end

end

end
end
end
