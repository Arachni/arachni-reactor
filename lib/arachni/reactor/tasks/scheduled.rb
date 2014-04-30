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
# {Base Task} occurring after {#interval} seconds.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Scheduled < Periodic

    # @note Will call {#done} right after.
    #
    # @return   [Object, nil]
    #   Return value of the configured task or `nil` if it's not
    #   {#interval time} yet.
    def call
        return if !call?

        call_task.tap { done }
    end

end

end
end
end
