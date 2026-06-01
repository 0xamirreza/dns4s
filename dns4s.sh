#!/usr/bin/env bash

set -e

RESOLVED_CONF="/etc/systemd/resolved.conf"

print_status() {
    echo "Current DNS configuration:"
    echo "---------------------------"

    resolvectl status | grep "DNS Servers" -A2 || true

    echo ""
    echo "Configured in resolved.conf:"
    grep -E "DNS=|FallbackDNS=" $RESOLVED_CONF || true
}

validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Invalid IP: $ip"
        exit 1
    fi
}

set_dns() {

    DNS_INPUT=$1
    FALLBACK=$2

    IFS=',' read -ra DNS_ARRAY <<< "$DNS_INPUT"

    if [ "${#DNS_ARRAY[@]}" -ne 2 ]; then
        echo "You must provide exactly two DNS servers."
        exit 1
    fi

    validate_ip "${DNS_ARRAY[0]}"
    validate_ip "${DNS_ARRAY[1]}"
    validate_ip "$FALLBACK"

    echo "Applying DNS configuration..."
    echo "Primary DNS: ${DNS_ARRAY[0]} ${DNS_ARRAY[1]}"
    echo "Fallback DNS: $FALLBACK"

    sudo tee $RESOLVED_CONF > /dev/null <<EOF
[Resolve]
DNS=${DNS_ARRAY[0]} ${DNS_ARRAY[1]}
FallbackDNS=$FALLBACK
DNSStubListener=yes
EOF

    sudo systemctl restart systemd-resolved

    echo ""
    echo "DNS updated successfully."
}

reset_dns() {

    echo "Resetting DNS configuration..."

    sudo rm -f $RESOLVED_CONF

    sudo systemctl restart systemd-resolved

    echo "Reset complete."
}

case "$1" in

status)
    print_status
    ;;

set)
    shift

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --dns)
                DNS="$2"
                shift
                ;;
            --fallback)
                FALLBACK="$2"
                shift
                ;;
        esac
        shift
    done

    if [[ -z "$DNS" || -z "$FALLBACK" ]]; then
        echo "Usage:"
        echo "./dns-force.sh set --dns 1.1.1.1,8.8.8.8 --fallback 9.9.9.9"
        exit 1
    fi

    set_dns "$DNS" "$FALLBACK"
    ;;

reset)
    reset_dns
    ;;

*)
    echo "DNS Manager CLI"
    echo ""
    echo "Commands:"
    echo "  status                     Show current DNS"
    echo "  set --dns A,B --fallback C Set DNS"
    echo "  reset                      Reset DNS"
    ;;

esac
