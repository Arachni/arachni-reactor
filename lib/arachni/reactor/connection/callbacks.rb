=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Connection

# Callbacks to be invoked per event.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Callbacks

    # Called after the connection has been established.
    #
    # @abstract
    def on_connect
    end

    # Called after the connection has been attached to a {#reactor}.
    #
    # @abstract
    def on_attach
    end

    # Called right the connection is detached from the {#reactor}.
    #
    # @abstract
    def on_detach
    end

    # @note If a connection could not be established no {#socket} may be
    #   available.
    #
    # Called when the connection gets closed.
    #
    # @param    [Exception] reason
    #   Reason for the close.
    #
    # @abstract
    def on_close( reason )
    end

    # Called when data are available.
    #
    # @param    [String] data
    #   Incoming data.
    #
    # @abstract
    def on_read( data )
    end

    # Called after each {#write} call.
    #
    # @abstract
    def on_write
    end

    # Called after the {#write buffered data} have all been sent to the peer.
    #
    # @abstract
    def on_flush
    end

end

end
end
end
