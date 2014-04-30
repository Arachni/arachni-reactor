=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

module Arachni
class Reactor
class Tasks

# {#call Callable} task.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Base

    # @return   [Tasks]
    #   List managing this task.
    attr_accessor :owner

    # @param    [Block] task
    def initialize( &task )
        fail ArgumentError, 'Missing block.' if !block_given?

        @task = task
    end

    # Calls the {#initialize configured} task and passes `self` to it.
    #
    # @abstract
    def call
        fail NotImplementedError
    end

    # {Tasks#delete Removes} the task from the {#owner}'s list.
    def done
        @owner.delete self
    end

    def hash
        @task.hash
    end

    private

    def call_task
        @task.call self
    end

end

end
end
end
