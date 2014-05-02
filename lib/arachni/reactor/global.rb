=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

require 'singleton'

module Arachni
class Reactor

# **Do not use directly!**
#
# Use the {Reactor} class methods to manage a globally accessible {Reactor}
# instance.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
# @private
class Global < Reactor
    include Singleton
end

end
end
