require 'ap'
require_relative '../lib/arachni/reactor'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each do |f|
    next if f.include? '/servers/'
    require f
end

RSpec.configure do |config|
    config.color = true
    config.add_formatter :documentation

    config.after(:all) do
        Servers.killall
    end
end
