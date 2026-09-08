# DNS4S — DNS Manager CLI

A lightweight **Bash CLI tool for Linux** to manage system DNS configuration.

DNS4S automatically detects the DNS backend available on the system and applies the configuration using the appropriate mechanism.

Supported backends:

* `systemd-resolved`
* `NetworkManager`
* `/etc/resolv.conf` fallback

It is designed as a simple **driver-style CLI tool**, similar to utilities such as `git`, `docker`, and `nmcli`.

---

# Features

* Simple command-based CLI
* Automatic DNS backend detection
* Configure two primary DNS servers
* Configure a fallback DNS server
* IPv4 validation
* Validate IPv4 octets (`0-255`)
* Show current DNS configuration
* Reset DNS configuration
* Support for systems without `systemd-resolved`
* NetworkManager support
* `/etc/resolv.conf` fallback
* Automatic backup of `resolv.conf` before modification
* Works with or without running the command as `root`

---

# Supported DNS Backends

DNS4S automatically detects the available DNS configuration mechanism.

## 1. systemd-resolved

If `systemd-resolved` and `resolvectl` are available, DNS4S uses:

```text
/etc/systemd/resolved.conf
```

and restarts:

```text
systemd-resolved.service
```

The fallback DNS configuration is supported by this backend.

---

## 2. NetworkManager

If NetworkManager is active, DNS4S configures DNS through:

```text
nmcli
```

The active NetworkManager connection is detected automatically.

DNS4S disables automatically obtained DNS servers and configures the specified primary DNS servers.

> Note: `--fallback` is not separately supported by NetworkManager because NetworkManager does not expose the same `FallbackDNS` mechanism as `systemd-resolved`.

---

## 3. `/etc/resolv.conf`

If neither `systemd-resolved` nor an active NetworkManager instance is available, DNS4S falls back to:

```text
/etc/resolv.conf
```

The file is updated with the specified DNS servers.

Before modifying a regular `/etc/resolv.conf`, DNS4S creates:

```text
/etc/resolv.conf.dns4s-backup
```

This backup is used by `dns4s reset`.

---

# Requirements

* Linux
* Bash
* IPv4 networking
* `systemctl` is recommended for service-based backends
* `sudo` is required when the script is not executed as `root`

Optional dependencies:

### systemd-resolved backend

```text
systemd-resolved
resolvectl
```

### NetworkManager backend

```text
NetworkManager
nmcli
```

DNS4S does not require `systemd-resolved` to be installed.

---

# Tested Systems

DNS4S is designed for Linux distributions using common DNS management mechanisms.

Known environments include:

* Arch Linux
* Manjaro Linux
* Ubuntu
* Debian
* Other systemd-based Linux distributions

The actual backend depends on the DNS/network configuration of the system.

---

# Installation

Clone the repository:

```bash
git clone <repository-url>
cd dns4s
```

Make the script executable:

```bash
chmod +x dns4s.sh
```

Run it directly:

```bash
./dns4s.sh
```

Optionally, install it globally:

```bash
sudo cp dns4s.sh /usr/local/bin/dns4s
sudo chmod +x /usr/local/bin/dns4s
```

Then use:

```bash
dns4s status
```

---

# Usage

```bash
dns4s <command> [options]
```

Available commands:

```text
status
set
reset
help
```

---

# Commands

## Show DNS Status

Display the detected DNS backend and current DNS configuration:

```bash
dns4s status
```

Example with `systemd-resolved`:

```text
DNS4S Status
============

Backend: systemd-resolved

Active DNS configuration:
-------------------------
DNS Servers: 178.22.122.101
             185.51.200.1

Configured in resolved.conf:
----------------------------
DNS=178.22.122.101 185.51.200.1
FallbackDNS=9.9.9.9
DNSStubListener=yes

/etc/resolv.conf:
-----------------
Symlink -> /run/systemd/resolve/stub-resolv.conf
```

Example with `/etc/resolv.conf`:

```text
DNS4S Status
============

Backend: resolv.conf

Current /etc/resolv.conf:
-------------------------
nameserver 178.22.122.101
nameserver 185.51.200.1
```

---

# Set DNS Servers

Configure two primary DNS servers and one fallback DNS:

```bash
dns4s set --dns <DNS1,DNS2> --fallback <DNS>
```

Example:

```bash
dns4s set \
  --dns 178.22.122.101,185.51.200.1 \
  --fallback 9.9.9.9
```

Another example:

```bash
dns4s set \
  --dns 1.1.1.1,8.8.8.8 \
  --fallback 9.9.9.9
```

DNS4S will:

1. Validate all IPv4 addresses.
2. Detect the active DNS backend.
3. Apply the DNS configuration using that backend.
4. Restart/reload the relevant networking component when required.
5. Report the backend used.

Example:

```text
Applying DNS configuration...
Primary DNS: 178.22.122.101 185.51.200.1
Fallback DNS: 9.9.9.9

Using backend: systemd-resolved

DNS updated successfully.
Backend: systemd-resolved
```

---

# Reset DNS Configuration

Reset the DNS configuration:

```bash
dns4s reset
```

The reset behavior depends on the detected backend.

### systemd-resolved

DNS4S removes:

```text
/etc/systemd/resolved.conf
```

and restarts:

```text
systemd-resolved.service
```

### NetworkManager

DNS4S removes the manually configured DNS servers and restores automatic DNS configuration.

### `/etc/resolv.conf`

If DNS4S previously created:

```text
/etc/resolv.conf.dns4s-backup
```

the original file is restored automatically.

---

# Example Workflow

Check the current DNS configuration:

```bash
dns4s status
```

Set DNS:

```bash
sudo dns4s set \
  --dns 1.1.1.1,8.8.8.8 \
  --fallback 9.9.9.9
```

Check the result:

```bash
dns4s status
```

Reset:

```bash
sudo dns4s reset
```

---

# IPv4 Validation

DNS4S validates IPv4 addresses before modifying the system.

Valid:

```text
1.1.1.1
8.8.8.8
178.22.122.101
```

Invalid:

```text
999.999.999.999
1.1.1
1.1.1.256
abc.def.ghi.jkl
```

Only IPv4 addresses are currently supported.

IPv6 support is not currently implemented.

---

# Permissions

DNS configuration requires administrative privileges.

You can run DNS4S as `root`:

```bash
sudo dns4s status
```

or:

```bash
sudo dns4s set --dns 1.1.1.1,8.8.8.8 --fallback 9.9.9.9
```

However, read-only commands such as:

```bash
dns4s status
```

normally do not require `sudo`.

When DNS4S needs administrative privileges, it automatically uses `sudo` if it is not already running as `root`.

---

# Configuration Files

Depending on the detected backend, DNS4S may modify one of the following:

### systemd-resolved

```text
/etc/systemd/resolved.conf
```

### NetworkManager

NetworkManager connection configuration through:

```text
nmcli
```

### Generic fallback

```text
/etc/resolv.conf
```

A backup may be created at:

```text
/etc/resolv.conf.dns4s-backup
```

---

# DNS Backend Detection

DNS4S follows this general detection order:

```text
                 ┌──────────────────────┐
                 │       dns4s          │
                 └──────────┬───────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │ systemd-resolved +    │
                │ resolvectl available? │
                └───────────┬───────────┘
                            │
                   Yes ─────┴───── No
                   │                │
                   ▼                ▼
          systemd-resolved   ┌────────────────┐
                              │ NetworkManager │
                              │    active?     │
                              └───────┬────────┘
                                      │
                              Yes ─────┴───── No
                              │                │
                              ▼                ▼
                       NetworkManager    /etc/resolv.conf
```

This allows DNS4S to work on systems where `systemd-resolved` is not installed.

---

# Design Goals

DNS4S is intentionally designed to remain lightweight.

The project aims to provide:

* Minimal dependencies
* Simple Bash implementation
* Automatic backend detection
* Safe DNS configuration
* Clear CLI output
* Linux compatibility
* Easy installation
* Predictable reset behavior

DNS4S does not attempt to replace full network-management systems such as NetworkManager or systemd.

Instead, it acts as a small DNS configuration layer over the existing system networking stack.

---

# Limitations

Current limitations:

* IPv6 is not supported.
* Exactly two primary DNS servers are required.
* `--fallback` has full semantic support only with `systemd-resolved`.
* `/etc/resolv.conf` may be managed by another service and can therefore be overwritten after DNS4S changes it.
* NetworkManager configuration currently targets the first active connection.
* Complex multi-interface DNS configurations are not currently supported.

---

# Troubleshooting

## systemd-resolved is not installed

If you see:

```text
Unit systemd-resolved.service not found.
```

DNS4S does not require you to install `systemd-resolved`.

It will automatically try NetworkManager and then `/etc/resolv.conf`.

Check the detected backend:

```bash
dns4s status
```

---

## Check `/etc/resolv.conf`

```bash
cat /etc/resolv.conf
```

---

## Check systemd-resolved

```bash
systemctl status systemd-resolved
```

and:

```bash
resolvectl status
```

---

## Check NetworkManager

```bash
systemctl status NetworkManager
```

and:

```bash
nmcli device show
```

---

# Security Considerations

DNS4S modifies system-level DNS configuration.

Always review the DNS servers you provide before applying them.

For example:

```bash
dns4s set \
  --dns 1.1.1.1,8.8.8.8 \
  --fallback 9.9.9.9
```

Only use DNS resolvers you trust.

---

# License

MIT License

```

یک نکته مهم: در README بالا عمداً عبارت **"Fallback DNS"** را برای کل CLI نگه داشتم، ولی صریحاً توضیح دادم که این مفهوم در `systemd-resolved` واقعی است و در NetworkManager / `resolv.conf` معادل مستقیمی ندارد. این باعث می‌شود مستندات با رفتار واقعی کد تناقض نداشته باشند.
```
