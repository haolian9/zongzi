function proxy_off
    set -e http_proxy
    set -e https_proxy
    echo "no more proxy env vars"
end
