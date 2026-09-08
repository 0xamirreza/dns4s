```bash
#!/usr/bin/env bash

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLV_CONF="/etc/resolv.conf"

# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

log_error() {
    echo "Error: $*" >&2
}

log_warn() {
    echo "Warning: $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1
}

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ---------------------------------------------------------
# DNS Backend Detection
# ---------------------------------------------------------

detect_backend() {

    # systemd-resolved
    if require_command resolvectl && \
       systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1 && \
       systemctl list-unit-files systemd-resolved.service 2>/dev/null \
           | grep -q '^systemd-resolved.service'; then

        echo "systemd-resolved"
        return
    fi

    # NetworkManager
    if require_command nmcli && systemctl is-active --quiet NetworkManager 2>/dev/null; then
        echo "networkmanager"
        return
    fi

    # resolv.conf fallback
    echo "resolv.conf"
}

# ---------------------------------------------------------
# IPv4 Validation
# ---------------------------------------------------------

validate_ip() {

    local ip="$1"
    local octet

    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log_error "Invalid IPv4 address: $ip"
        exit 1
    fi

    IFS='.' read -r -a octets <<< "$ip"

    for octet in "${octets[@]}"; do
        if (( octet < 0 || octet > 255 )); then
            log_error "Invalid IPv4 address: $ip"
            exit 1
        fi
    done
}

# ---------------------------------------------------------
# DNS Configuration
# ---------------------------------------------------------

set_dns_resolved() {

    local dns1="$1"
    local dns2="$2"
    local fallback="$3"

    echo "Using backend: systemd-resolved"

    run_root mkdir -p "$(dirname "$RESOLVED_CONF")"

    run_root tee "$RESOLVED_CONF" >/dev/null <<EOF
[Resolve]
DNS=$dns1 $dns2
FallbackDNS=$fallback
DNSStubListener=yes
EOF

    if ! run_root systemctl restart systemd-resolved; then
        log_error "Failed to restart systemd-resolved."
        return 1
    fi

    # Make sure /etc/resolv.conf points to systemd-resolved stub.
    if [[ -L "$RESOLV_CONF" ]]; then
        local target
        target="$(readlink "$RESOLV_CONF")"

        if [[ "$target" != "/run/systemd/resolve/stub-resolv.conf" ]]; then
            log_warn "/etc/resolv.conf does not point to systemd-resolved stub."
        fi
    else
        log_warn "/etc/resolv.conf is not a symlink to systemd-resolved."
    fi
}

set_dns_networkmanager() {

    local dns1="$1"
    local dns2="$2"

    echo "Using backend: NetworkManager"

    local connection

    connection="$(nmcli -t -f NAME connection show --active 2>/dev/null | head -n1 || true)"

    if [[ -z "$connection" ]]; then
        log_error "No active NetworkManager connection found."
        return 1
    fi

    echo "Active connection: $connection"

    run_root nmcli connection modify "$connection" \
        ipv4.ignore-auto-dns yes \
        ipv4.dns "$dns1,$dns2"

    run_root nmcli connection up "$connection" >/dev/null
}

set_dns_resolv_conf() {

    local dns1="$1"
    local dns2="$2"

    echo "Using backend: /etc/resolv.conf"

    # Backup current resolv.conf once.
    if [[ -f "$RESOLV_CONF" && ! -L "$RESOLV_CONF" ]]; then
        if [[ ! -f "${RESOLV_CONF}.dns4s-backup" ]]; then
            run_root cp "$RESOLV_CONF" "${RESOLV_CONF}.dns4s-backup"
        fi
    fi

    run_root tee "$RESOLV_CONF" >/dev/null <<EOF
# Managed by dns4s
nameserver $dns1
nameserver $dns2
EOF
}

# ---------------------------------------------------------
# Set DNS
# ---------------------------------------------------------

set_dns() {

    local DNS_INPUT="$1"
    local FALLBACK="$2"

    local DNS_ARRAY

    IFS=',' read -ra DNS_ARRAY <<< "$DNS_INPUT"

    if [[ "${#DNS_ARRAY[@]}" -ne 2 ]]; then
        log_error "You must provide exactly two DNS servers."
        exit 1
    fi

    local dns1="${DNS_ARRAY[0]}"
    local dns2="${DNS_ARRAY[1]}"

    validate_ip "$dns1"
    validate_ip "$dns2"
    validate_ip "$FALLBACK"

    echo "Applying DNS configuration..."
    echo "Primary DNS: $dns1 $dns2"
    echo "Fallback DNS: $FALLBACK"
    echo ""

    local backend
    backend="$(detect_backend)"

    case "$backend" in

        systemd-resolved)
            set_dns_resolved "$dns1" "$dns2" "$FALLBACK"
            ;;

        networkmanager)
            set_dns_networkmanager "$dns1" "$dns2"
            ;;

        resolv.conf)
            set_dns_resolv_conf "$dns1" "$dns2"
            ;;

        *)
            log_error "Unknown DNS backend: $backend"
            exit 1
            ;;
    esac

    echo ""
    echo "DNS updated successfully."
    echo "Backend: $backend"
}

# ---------------------------------------------------------
# Status
# ---------------------------------------------------------

print_status() {

    echo "DNS4S Status"
    echo "============"
    echo ""

    local backend
    backend="$(detect_backend)"

    echo "Backend: $backend"
    echo ""

    case "$backend" in

        systemd-resolved)

            echo "Active DNS configuration:"
            echo "-------------------------"

            if require_command resolvectl; then
                resolvectl status 2>/dev/null \
                    | grep -E "DNS Servers|DNS Domain" -A2 \
                    || true
            fi

            echo ""
            echo "Configured in resolved.conf:"
            echo "----------------------------"

            if [[ -f "$RESOLVED_CONF" ]]; then
                grep -E "^[[:space:]]*(DNS|FallbackDNS|DNSStubListener)=" \
                    "$RESOLVED_CONF" || true
            else
                echo "No dns4s configuration found."
            fi

            echo ""
            echo "/etc/resolv.conf:"
            echo "-----------------"

            if [[ -L "$RESOLV_CONF" ]]; then
                echo "Symlink -> $(readlink "$RESOLV_CONF")"
            else
                echo "Regular file"
            fi

            ;;

        networkmanager)

            echo "Active NetworkManager DNS:"
            echo "--------------------------"

            nmcli device show 2>/dev/null \
                | grep -E "IP4.DNS|IP6.DNS" \
                || true

            echo ""
            echo "Active connections:"
            nmcli -t -f NAME,DEVICE connection show --active \
                2>/dev/null || true

            ;;

        resolv.conf)

            echo "Current /etc/resolv.conf:"
            echo "-------------------------"

            if [[ -f "$RESOLV_CONF" ]]; then
                grep -E "^[[:space:]]*nameserver[[:space:]]+" \
                    "$RESOLV_CONF" || true
            else
                echo "File not found."
            fi

            ;;

    esac
}

# ---------------------------------------------------------
# Reset
# ---------------------------------------------------------

reset_dns() {

    echo "Resetting DNS configuration..."
    echo ""

    local backend
    backend="$(detect_backend)"

    case "$backend" in

        systemd-resolved)

            if [[ -f "$RESOLVED_CONF" ]]; then
                run_root rm -f "$RESOLVED_CONF"
            fi

            run_root systemctl restart systemd-resolved

            echo "systemd-resolved configuration reset."
            ;;

        networkmanager)

            local connection

            connection="$(nmcli -t -f NAME connection show --active \
                2>/dev/null | head -n1 || true)"

            if [[ -z "$connection" ]]; then
                log_error "No active NetworkManager connection found."
                exit 1
            fi

            run_root nmcli connection modify "$connection" \
                ipv4.ignore-auto-dns no \
                ipv4.dns ""

            run_root nmcli connection up "$connection" >/dev/null

            echo "NetworkManager DNS configuration reset."
            ;;

        resolv.conf)

            if [[ -f "${RESOLV_CONF}.dns4s-backup" ]]; then

                run_root cp \
                    "${RESOLV_CONF}.dns4s-backup" \
                    "$RESOLV_CONF"

                run_root rm \
                    -f "${RESOLV_CONF}.dns4s-backup"

                echo "/etc/resolv.conf restored from backup."

            else

                log_warn "No dns4s backup found."

                echo "Removing dns4s managed configuration..."

                run_root rm -f "$RESOLV_CONF"

                run_root touch "$RESOLV_CONF"

                echo "Created empty /etc/resolv.conf."
            fi

            ;;

    esac

    echo ""
    echo "Reset complete."
}

# ---------------------------------------------------------
# Help
# ---------------------------------------------------------

print_help() {

    cat <<EOF
DNS4S - DNS Manager CLI

Usage:
  dns4s <command> [options]

Commands:

  status
      Show current DNS configuration.

  set --dns A,B --fallback C
      Set two primary DNS servers and one fallback DNS.

  reset
      Reset DNS configuration.

Examples:

  dns4s set --dns 178.22.122.101,185.51.200.1 --fallback 9.9.9.9

  dns4s status

  dns4s reset
EOF
}

# ---------------------------------------------------------
# Argument Parser
# ---------------------------------------------------------

case "${1:-}" in

    status)

        print_status
        ;;

    set)

        shift

        DNS=""
        FALLBACK=""

        while [[ "$#" -gt 0 ]]; do

            case "$1" in

                --dns)

                    if [[ -z "${2:-}" ]]; then
                        log_error "--dns requires a value."
                        exit 1
                    fi

                    DNS="$2"
                    shift 2
                    ;;

                --fallback)

                    if [[ -z "${2:-}" ]]; then
                        log_error "--fallback requires a value."
                        exit 1
                    fi

                    FALLBACK="$2"
                    shift 2
                    ;;

                *)

                    log_error "Unknown option: $1"
                    print_help
                    exit 1
                    ;;

            esac

        done

        if [[ -z "$DNS" || -z "$FALLBACK" ]]; then

            log_error "Missing required options."
            echo ""

            print_help

            exit 1
        fi

        set_dns "$DNS" "$FALLBACK"
        ;;

    reset)

        reset_dns
        ;;

    -h|--help|help)

        print_help
        ;;

    "")

        print_help
        ;;

    *)

        log_error "Unknown command: $1"
        echo ""

        print_help

        exit 1
        ;;

esac
```
