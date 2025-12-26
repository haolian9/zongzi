function proxy_on
    export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"

    set -l addr '127.0.0.1:8118'
    if set -q argv[1]
        set addr $argv[1]
    end

    if not string match -rq '^[\d.]+:\d+$' $addr
        echo "invalid address:" $addr >&2
        return 1
    end

    echo "using proxy: '$addr'"
    export http_proxy="http://$addr/"
    export https_proxy=$http_proxy
end
