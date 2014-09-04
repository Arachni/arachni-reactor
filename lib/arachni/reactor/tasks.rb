=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require 'mutex_m'

require_relative 'tasks/base'
require_relative 'tasks/persistent'
require_relative 'tasks/one_off'
require_relative 'tasks/periodic'
require_relative 'tasks/delayed'

module Arachni
class Reactor

# {Tasks::Base Task} list.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Tasks
    include Mutex_m

    def initialize
        super

        @tasks = []
    end

    # @note Only {Base#hash unique} tasks will be included.
    # @note Will assign `self` as the task's {Base#owner owner}.
    #
    # @param    [Base]  task
    #   Task to add to the list.
    # @return   [Tasks] `self`
    def <<( task )
        synchronize do
            task.owner = self
            @tasks << task
        end

        self
    end

    # @param    [Base]  task
    #   Task to check.
    # @return   [Bool]
    def include?( task )
        @tasks.include? task
    end

    # @param    [Base]  task
    #   Task to remove from the list.
    # @return   [Base,nil]
    #   The task if it was included, `nil` otherwise.
    def delete( task )
        synchronize do
            task = @tasks.delete( task )
            task.owner = nil if task
            task
        end
    end

    # @return   [Integer]
    def size
        @tasks.size
    end

    # @return   [Bool]
    def empty?
        @tasks.empty?
    end

    # @return   [Bool]
    def any?
        !empty?
    end

    # Removes all tasks.
    #
    # @return   [Tasks] `self`
    def clear
        synchronize do
            @tasks.clear
        end

        self
    end

    # {Base#call Calls} all tasks.
    #
    # @return   [Tasks] `self`
    def call( *args )
        @tasks.dup.each { |t| t.call *args }
        self
    end

    def hash
        @tasks.hash
    end

end

end
end
