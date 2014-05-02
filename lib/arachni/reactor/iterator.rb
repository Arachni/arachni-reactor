
=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor

# @note Pretty much an `EventMachine::Iterator` rip-off.
#
# A simple iterator for concurrent asynchronous work.
#
# Unlike Ruby's built-in iterators, the end of the current iteration cycle is
# signaled manually, instead of happening automatically after the yielded block
# finishes executing.
#
# @example Direct initialization.
#
#     Iterator.new( reactor, 0..10 ).each { |num, iterator| iterator.next }
#
# @example Reactor factory.
#
#     reactor.create_iterator( 0..10 ).each { |num, iterator| iterator.next }
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Iterator

    # @return   [Reactor]
    attr_reader :reactor

    # @return   [Integer]
    attr_reader :concurrency

    # @example Create a new parallel async iterator with specified concurrency.
    #
    #     i = Iterator.new( reactor, 1..100, 10 )
    #
    # @param    [Reactor]   reactor
    # @param    [#to_a] list
    #   List to iterate.
    # @param    [Integer]   concurrency
    #   Parallel workers to spawn.
    def initialize( reactor, list, concurrency = 1 )
        raise ArgumentError, 'argument must be an array' unless list.respond_to?(:to_a)
        raise ArgumentError, 'concurrency must be bigger than zero' unless concurrency > 0

        @reactor     = reactor
        @list        = list.to_a.dup
        @concurrency = concurrency

        @started = false
        @ended   = false
    end

    # Change the concurrency of this iterator. Workers will automatically be
    # spawned or destroyed to accommodate the new concurrency level.
    #
    # @param    [Integer]   val
    #   New concurrency.
    def concurrency=( val )
        old          = @concurrency
        @concurrency = val

        spawn_workers if val > old && @started && !@ended

        val
    end

    # @example Iterate over a set of items using the specified block or proc.
    #
    #   Iterator.new( reactor, 1..100 ).each do |num, iterator|
    #       puts num
    #       iterator.next
    #   end
    #
    # @example An optional second proc is invoked after the iteration is complete.
    #
    #   Iterator.new( reactor, 1..100 ).each(
    #       proc { |num, iterator| iterator.next },
    #       proc { puts 'all done' }
    #   )
    def each( foreach = nil, after = nil, &block )
        raise ArgumentError, 'Proc or Block required for iteration.' unless foreach ||= block
        raise RuntimeError, 'Cannot iterate over an iterator more than once.' if @started or @ended

        @started = true
        @pending = 0
        @workers = 0

        all_done = proc do
            after.call if after && @ended && @pending == 0
        end

        @process_next = proc do
            if @ended || @workers > @concurrency
                @workers -= 1
            else
                if @list.empty?
                    @ended    = true
                    @workers -= 1

                    all_done.call
                else
                    item      = @list.shift
                    @pending += 1

                    is_done = false
                    on_done = proc do
                        raise RuntimeError, 'Already completed this iteration.' if is_done
                        is_done = true

                        @pending -= 1

                        if @ended
                            all_done.call
                        else
                            @reactor.next_tick(&@process_next)
                        end
                    end

                    class << on_done
                        alias :next :call
                    end

                    foreach.call(item, on_done)
                end
            end
        end

        spawn_workers

        self
    end

    # @example Collect the results of an asynchronous iteration into an array.
    #
    #   Iterator.new( reactor, %w(one two three four), 2 ).map(
    #       proc do |string, iterator|
    #           iterator.return( string.size )
    #       end,
    #       proc do |results|
    #           p results
    #       end
    #   )
    #
    # @param    [Proc]  foreach
    #   `Proc` to handle each entry.
    # @param    [Proc]  after
    #   `Proc` to handle the results.
    def map( foreach, after )
        index = 0

        inject( [],
            proc do |results, item, iter|
                i      = index
                index += 1

                is_done = false
                on_done = proc do |res|
                    raise RuntimeError, 'Already returned a value for this iteration.' if is_done
                    is_done = true

                    results[i] = res
                    iter.return(results)
                end

                class << on_done
                    alias :return :call
                    def next
                        raise NoMethodError, 'Must call #return on a map iterator.'
                    end
                end

                foreach.call( item, on_done )
            end,

            proc do |results|
                after.call(results)
            end
        )
    end

    # @example Inject the results of an asynchronous iteration onto a given object.
    #
    #   Iterator.new( reactor, %w(one two three four), 2 ).inject( {},
    #       proc do |hash, string, iterator|
    #           hash.merge!( string => string.size )
    #           iterator.return( hash )
    #       end,
    #       proc do |results|
    #           p results
    #       end
    #   )
    #
    # @param    [Object]  object
    # @param    [Proc]  foreach
    #   `Proc` to handle each entry.
    # @param    [Proc]  after
    #   `Proc` to handle the results.
    def inject( object, foreach, after )
        each(
            proc do |item, iter|
                is_done = false
                on_done = proc do |res|
                    raise RuntimeError, 'Already returned a value for this iteration.' if is_done
                    is_done = true

                    object = res
                    iter.next
                end

                class << on_done
                    alias :return :call
                    def next
                        raise NoMethodError, 'Must call #return on an inject iterator.'
                    end
                end

                foreach.call( object, item, on_done )
            end,

            proc do
                after.call(object)
            end
        )
    end

    private

    # Spawn workers to consume items from the iterator's enumerator based on the
    # current concurrency level.
    def spawn_workers
        @reactor.next_tick( &proc { |task|
            next if @workers >= @concurrency || @ended

            @workers += 1
            @process_next.call
            @reactor.next_tick(&task.to_proc)
        })

        nil
    end

end

end
end
