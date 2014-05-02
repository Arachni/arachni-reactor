class EchoClient < Arachni::Reactor::Connection

    attr_reader :initialization_args
    attr_reader :received_data

    attr_reader :error
    attr_reader :on_write_count
    attr_reader :called_on_flush

    def initialize( *args )
        @initialization_args = args
        @on_write_count      = 0
        @called_on_flush     = false
    end

    def on_write
        @on_write_count += 1
    end

    def on_flush
        @called_on_flush = !has_outgoing_data?
    end

    def on_close( error )
        @error = error
        @reactor.stop
    end

    def on_read( data )
        (@received_data ||= '') << data
        @reactor.stop if @received_data.end_with? "\n\n"
    end

end
