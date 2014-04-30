require 'ap'
require_relative '../../../../lib/arachni/reactor'

Thread.abort_on_exception = true

Dir["#{File.expand_path(File.dirname(__FILE__) + '/../..' )}/**/*.rb"].each do |f|
    next if f.include?( '/servers/' ) || f.include?( 'shared' )
    require f
end

$options = ServerOptionParser.parse

load ARGV[0]
