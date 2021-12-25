=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

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

        if @role == :server
            @socket = OpenSSL::SSL::SSLServer.new( @socket, @ssl_context )
        else
            @socket = OpenSSL::SSL::SSLSocket.new( @socket, @ssl_context )
            @socket.sync_close = true

            # We've switched to SSL, a connection needs to be re-established
            # via the SSL handshake.
            @connected         = false

            _connect if unix?
        end

        @socket
    end

    # Performs an SSL handshake in addition to a plaintext connect operation.
    #
    # @private
    def _connect
        return if @ssl_connected

        Error.translate do
            @plaintext_connected ||= super
            return if !@plaintext_connected

            # Mark the connection as not connected due to the pending SSL handshake.
            @connected = false

            @socket.connect_nonblock
            @ssl_connected = @connected = true
        end
    rescue IO::WaitReadable, IO::WaitWritable, Errno::EINPROGRESS
    rescue Error => e
        close e
    end

    # First checks if there's a pending SSL #accept operation when this
    # connection is a server handler which has been passed an accepted
    # plaintext connection.
    #
    # @private
    def _write( *args )
        return ssl_accept if accept?

        super( *args )
    end

    # First checks if there's a pending SSL #accept operation when this
    # connection is a server handler which has been passed an accepted
    # plaintext connection.
    #
    # @private
    def _read
        return ssl_accept if accept?

        super
    rescue OpenSSL::SSL::SSLErrorWaitReadable
    end

    private

    def ssl_accept
        Error.translate do
            @accepted = !!@socket.accept_nonblock
        end
    rescue IO::WaitReadable, IO::WaitWritable
    rescue Error => e
        close e
        false
    end

    def accept?
        return false if @accepted
        return false if role != :server || !@socket.is_a?( OpenSSL::SSL::SSLSocket )

        true
    end

    # Accepts a new SSL client connection.
    #
    # @return   [OpenSSL::SSL::SSLSocket, nil]
    #   New connection or `nil` if the socket isn't ready to accept new
    #   connections yet.
    #
    # @private
    def socket_accept
        Error.translate do
            socket = to_io.accept_nonblock

            ssl_socket = OpenSSL::SSL::SSLSocket.new(
                socket,
                @ssl_context
            )
            ssl_socket.sync_close = true
            ssl.accept if @start_immediately
            ssl_socket
        end
    rescue IO::WaitReadable, IO::WaitWritable
    rescue Error => e
        close e
    end

end

end
end
end
