class EchoClientTLS < EchoClient
    include TLS

    def on_connect
        start_tls
    end

end
