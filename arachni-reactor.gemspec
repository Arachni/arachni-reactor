=begin

    This file is part of the Arachni::Reactor project and may be subject to
    redistribution and commercial restrictions. Please see the Arachni::Reactor
    web site for more information on licensing and terms of use.

=end

Gem::Specification.new do |s|
    require File.expand_path( File.dirname( __FILE__ ) ) + '/lib/arachni/reactor/version'

    s.name              = 'arachni-reactor'
    s.license           = 'BSD 3-Clause'
    s.version           = Arachni::Reactor::VERSION
    s.date              = Time.now.strftime('%Y-%m-%d')
    s.summary           = 'A pure-Ruby implementation of the Reactor pattern.'
    s.homepage          = 'https://github.com/Arachni/arachni-reactor'
    s.email             = 'tasos.laskos@gmail.com'
    s.authors           = [ 'Tasos Laskos' ]

    s.files             = %w(README.md Rakefile LICENSE.md CHANGELOG.md)
    s.files            += Dir.glob('lib/**/**')
    s.test_files        = Dir.glob('spec/**/**')

    s.extra_rdoc_files  = %w(README.md LICENSE.md CHANGELOG.md)
    s.rdoc_options      = ['--charset=UTF-8']

    s.description = <<description
    Arachni::Reactor is a simple, lightweight, pure-Ruby implementation of the Reactor
    pattern, mainly focused on network connections -- and less so on generic tasks.
description

end
