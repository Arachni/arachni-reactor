
=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor

# @note Pretty much an `EventMachine::Queue` rip-off.
#
# A cross thread, {Reactor#schedule Reactor scheduled}, linear queue.
#
# This class provides a simple queue abstraction on top of the
# {Reactor#schedule scheduler}.
#
# It services two primary purposes:
#
# * API sugar for stateful protocols.
# * Pushing processing onto the {Reactor#thread reactor thread}.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Queue

    # @return   [Reactor]
    attr_reader :reactor

    # @param    [Reactor]   reactor
    def initialize( reactor )
        @reactor = reactor
        @items   = []
        @waiting = []
    end

    # @param    [Block] block
    #   Block to be {Reactor#schedule scheduled} by the {Reactor} and passed
    #   an item from the queue as soon as one becomes available.
    def pop( &block )
        @reactor.schedule do
            if @items.empty?
                @waiting << block
            else
                block.call @items.shift
            end
        end

        nil
    end

    # @param    [Object] item
    #   {Reactor#schedule Schedules} an item for addition to the queue.
    def push( item )
        @reactor.schedule do
            @items.push( item )
            @waiting.shift.call @items.shift until @items.empty? || @waiting.empty?
        end

        nil
    end
    alias :<< :push

    # @note This is a peek, it's not thread safe, and may only tend toward accuracy.
    #
    # @return [Boolean]
    def empty?
        @items.empty?
    end

    # @note This is a peek, it's not thread safe, and may only tend toward accuracy.
    #
    # @return [Integer]
    #   Queue size.
    def size
        @items.size
    end

    # @note Accuracy cannot be guaranteed.
    #
    # @return [Integer]
    #   Number of jobs that are currently waiting on the Queue for items to appear.
    def num_waiting
        @waiting.size
    end

end

end
end
