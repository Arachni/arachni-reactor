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

            begin
                @socket.connect_nonblock
            rescue IO::WaitReadable, IO::WaitWritable
            end
        end

        @socket
    end

    private

    # Accepts a new SSL client connection.
    #
    # @return   [OpenSSL::SSL::SSLSocket, nil]
    #   New connection or `nil` if the socket isn't ready to accept new
    #   connections yet.
    #
    # @private
    def socket_accept
        socket = nil
        begin
            socket = to_io.accept_nonblock
        rescue IO::WaitReadable, IO::WaitWritable
            return
        end

        socket = OpenSSL::SSL::SSLSocket.new(
            socket,
            @ssl_context
        )
        socket.sync_close = true

        begin
            socket.accept_nonblock
        rescue IO::WaitReadable, IO::WaitWritable
        end

        socket
    rescue OpenSSL::SSL::SSLError
    end

end

end
end
end
