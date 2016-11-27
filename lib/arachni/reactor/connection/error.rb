=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Connection

# {Connection} error namespace.
#
# All {Connection} errors inherit from and live under it.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Error < Arachni::Reactor::Error

    class << self
        # Captures Ruby exceptions and converts them to an appropriate
        # subclass of {Error}.
        #
        # @param  [Block] block Block to run.
        def translate( &block )
            block.call
        rescue IOError, Errno::ENOTCONN, Errno::ENOTSOCK => e
            raise_with_proper_backtrace( e, Closed )
        rescue SocketError, Errno::ENOENT => e
            raise_with_proper_backtrace( e, HostNotFound )
        rescue Errno::EPIPE => e
            raise_with_proper_backtrace( e, BrokenPipe )
        rescue Errno::ECONNREFUSED,
            # JRuby throws Errno::EADDRINUSE when trying to connect to a
            # non-existent server.
            Errno::EADDRINUSE => e
            raise_with_proper_backtrace( e, Refused )
        rescue Errno::ECONNRESET, Errno::ECONNABORTED => e
            raise_with_proper_backtrace( e, Reset )
        rescue Errno::EACCES => e
            raise_with_proper_backtrace( e, Permission )

        # Catch and forward these before handling OpenSSL::OpenSSLError because
        # all SSL errors inherit from it, including OpenSSL::SSL::SSLErrorWaitReadable
        # and OpenSSL::SSL::SSLErrorWaitWritable which also inherit from
        # IO::WaitReadable and IO::WaitWritable and need special treatment.
        rescue IO::WaitReadable, IO::WaitWritable, Errno::EINPROGRESS
            raise

        # We're mainly interested in translating SSL handshake errors but there
        # aren't any specific exceptions for these.
        #
        # Why make things easy and clean, right?
        rescue OpenSSL::SSL::SSLError, OpenSSL::OpenSSLError => e
            raise_with_proper_backtrace( e, SSL )
        end

        def raise_with_proper_backtrace( ruby, arachni )
            e = arachni.new( ruby.to_s )
            e.set_backtrace ruby.backtrace
            raise e
        end
    end

    # Like a `SocketError.getaddrinfo` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class HostNotFound < Error
    end

    # Like a `Errno::EACCES` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Permission < Error
    end

    # Like a `Errno::ECONNREFUSED` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Refused < Error
    end

    # Like a `Errno::ECONNRESET` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Reset < Error
    end

    # Like a `Errno::EPIPE` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class BrokenPipe < Error
    end

    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Timeout < Error
    end

    # Like a `IOError` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Closed < Error
    end

    # Like a `OpenSSL::OpenSSLError` exception.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class SSL < Error
    end

end
end
end
end
