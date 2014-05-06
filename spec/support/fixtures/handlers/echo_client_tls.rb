require_relative 'echo_client'

class EchoClientTLS < EchoClient
    include TLS

    def on_connect
        start_tls
    end

end
