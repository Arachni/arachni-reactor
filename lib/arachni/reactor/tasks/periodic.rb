=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Tasks

# @note {#interval Time} accuracy cannot be guaranteed.
#
# {Base Task} occurring every {#interval} seconds.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Periodic < Persistent

    # @return   [Float]
    attr_reader :interval

    # @param    [Float] interval
    #   Needs to be greater than `0.0`.
    # @param    [#call] task
    def initialize( interval, &task )
        interval = interval.to_f
        fail ArgumentError, 'Interval needs to be greater than 0.' if interval <= 0

        super( &task )

        @interval = interval
        calculate_next
    end

    # @return   [Object, nil]
    #   Return value of the configured task or `nil` if it's not
    #   {#interval time} yet.
    def call( *args )
        return if !call?
        calculate_next

        super( *args )
    end

    private

    def call?
        Time.now >= @next
    end

    def calculate_next
        @next = Time.now + @interval
    end

end

end
end
end
