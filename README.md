# DNS Manager CLI (Linux / Manjaro / Arch)

A lightweight **Bash CLI tool** to manage system DNS configuration using **systemd-resolved**.

This script allows you to:

- View current DNS configuration
- Set two primary DNS servers
- Configure a fallback DNS server
- Reset DNS settings to default

It is designed as a **driver-style CLI tool**, similar to utilities like `git`, `docker`, and `nmcli`.

---

# Features

- Simple CLI interface
- Configure two primary DNS servers
- Configure one fallback DNS
- Validate IPv4 input
- Show current DNS configuration
- Reset configuration to default
- Uses systemd-resolved

---

# Requirements

- Linux system with systemd
- systemd-resolved
- resolvectl

Tested on:

- Manjaro Linux
- Arch Linux
- systemd-based distributions

---

# Installation

Clone the repository or download the script.

```
git clone <repository-url>
cd dns-manager
```

Make the script executable:

```
chmod +x dns4s.sh
```

---

# Usage

The script uses a command-based CLI interface.

```
./dns4s.sh <command> [options]
```

---

# Commands

## Show Current DNS

Displays the active DNS configuration and fallback DNS.

```
./dns4s.sh status
```

Example output:

```
Current DNS configuration:
DNS Servers: 1.1.1.1
             8.8.8.8

FallbackDNS=9.9.9.9
```

---

## Set DNS Servers

Configure two primary DNS servers and one fallback DNS.

```
sudo ./dns4s.sh set --dns <DNS1,DNS2> --fallback <DNS>
```

Example:

```
sudo ./dns4s.sh set --dns 1.1.1.1,8.8.8.8 --fallback 9.9.9.9
```

This command will:

- Update /etc/systemd/resolved.conf
- Configure primary DNS servers
- Configure fallback DNS
- Restart systemd-resolved

---

## Reset DNS Configuration

Restores the DNS configuration to default.

```
sudo ./dns4s.sh reset
```

This will:

- Remove custom DNS settings
- Restart systemd-resolved

---

# Example Workflow

Check current DNS:

```
./dns4s.sh status
```

Set new DNS:

```
sudo ./dns4s.sh set --dns 1.1.1.1,8.8.8.8 --fallback 9.9.9.9
```

Verify configuration:

```
./dns4s.sh status
```

---

# File Modified

The script updates the following configuration file:

```
/etc/systemd/resolved.conf
```

After modification, the service is restarted:

```
systemctl restart systemd-resolved
```

---

# Notes

- The script expects exactly two primary DNS servers.
- Only IPv4 addresses are currently supported.
- Administrative privileges (sudo) are required for configuration changes.

---

# License

MIT License
