require 'optparse'

class ServerOptionParser

    DEFAULT = {
        host: '0.0.0.0',
        port: 4567
    }

    def self.parse
        options = {}

        OptionParser.new do |opts|

            opts.on('-o', '--host [host]',
                    "Sets the host (default is #{options[:host]}).") do |host|
                options[:host] = host
            end

            opts.on('-p', '--port [port]', Integer,
                    "Sets the port (default is #{options[:port]}).") do |port|
                options[:port] = port
            end

        end.parse!

        DEFAULT.merge(options)
    end
end
