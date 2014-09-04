=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Tasks

# {Base Task} occurring at the next tick and then marking itself as {#done}.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class OneOff < Base

    # Performs the task and marks it as {#done}.
    #
    # @return   [Object]
    #   Return value of the task.
    def call( *args )
        call_task( *args )
    ensure
        done
    end

end

end
end
end
