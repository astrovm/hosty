# hosty

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrovm/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrovm/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrovm/hosty.svg)
![GitHub watchers](https://img.shields.io/github/watchers/astrovm/hosty.svg?label=Watch&style=social)
![GitHub stars](https://img.shields.io/github/stars/astrovm/hosty.svg?label=Star&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrovm/hosty.svg?label=Fork&style=social)](https://github.com/astrovm/hosty)

Hosty is a system-wide hosts-file blocker for Unix-like operating systems. Its scripts use portable POSIX `sh` syntax and common Unix utilities; CI exercises Ubuntu, Alpine/BusyBox, macOS, FreeBSD, and OpenBSD.

Hosty downloads domain lists, combines them with custom rules, applies a whitelist, and writes the result to `/etc/hosts` without discarding existing entries.

The default lists focus on ads, tracking, spyware, malware, and other privacy threats. They intentionally avoid political censorship and paternalistic categories such as pornography or gambling.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Requirements

Required:

- a POSIX-compatible `/bin/sh`
- `curl`
- `awk`
- common Unix utilities: `cat`, `chmod`, `date`, `dirname`, `grep`, `head`, `id`, `mktemp`, `mv`, `rm`, and `sort`

Optional:

- `crontab`, for automatic updates
- `sudo` or `doas`, when installing or running Hosty from a non-root account

Most required utilities are included in the base system. Install missing packages with the platform package manager:

| Platform | Command |
|---|---|
| Debian, Ubuntu, Mint, Pop!_OS | `sudo apt install curl mawk cron` |
| Arch Linux, Manjaro, EndeavourOS | `sudo pacman -S --needed curl gawk cronie` |
| Fedora, RHEL, Rocky Linux | `sudo dnf install curl gawk cronie` |
| Alpine Linux | `apk add curl` (`cronie` is optional) |
| macOS | No additional package is normally required |
| FreeBSD | `pkg install curl` |
| OpenBSD | `pkg_add curl` |

Run package-manager commands as root. Prefix them with `sudo` or `doas` when configured.

## Install

```sh
curl -fsSL https://4st.li/hosty/install.sh | sh
```

The installer:

- runs directly when the current account is root
- otherwise uses `sudo`, falling back to `doas`
- downloads and validates Hosty before replacing an existing installation
- installs the executable at `/usr/local/bin/hosty`
- optionally configures automatic updates when `crontab` and a controlling terminal are available

Without a controlling terminal, installation remains non-interactive and skips the automatic-update prompt. Configure it later with `hosty --autorun` as root.

## Usage

Hosty must run as root when it changes the system:

```sh
sudo hosty
# or
doas hosty
```

### Automatic updates

```sh
sudo hosty --autorun
```

Choose `daily`, `weekly`, `monthly`, or `never`. Replace `sudo` with `doas` where appropriate.

### Debug without changing the system

```sh
hosty --debug
```

Debug mode builds the resulting hosts file in a temporary location and prints its path. It does not require root privileges.

### Restore the original hosts file

```sh
sudo hosty --restore
```

### Uninstall

```sh
sudo hosty --uninstall
```

Restore the hosts file first when you also want to disable the active block list.

## Custom rules

Hosty stores optional configuration under `/etc/hosty`.

### Blacklist

Add one domain per line to `/etc/hosty/blacklist`:

```text
facebook.com
www.facebook.com
```

### Whitelist

Add one domain per line to `/etc/hosty/whitelist`:

```text
4st.li
www.4st.li
```

### Custom sources

Add one URL per line to:

- `/etc/hosty/blacklist.sources` for domains to block
- `/etc/hosty/whitelist.sources` for domains to allow

Example:

```text
https://example.com/hosts.txt
```

Source files may contain plain domain names or hosts-style entries. Hosty extracts valid-looking domains from uncommented lines. It does not interpret browser filter-list syntax such as ABP, uBlock Origin, or AdGuard rules; use hosts-format versions of those lists instead.

Run only with custom sources and local rules:

```sh
sudo hosty --ignore-default-sources
```

Configure automatic updates in the same mode:

```sh
sudo hosty --autorun --ignore-default-sources
```

## Portability

The scripts avoid Bash-specific syntax and GNU-only text-processing behavior. They use POSIX shell syntax together with `curl`, `mktemp`, and common Unix utilities available on the supported systems.

Hosty uses these conventional paths and interfaces:

- `/etc/hosts`
- `/etc/hosty`
- `/usr/local/bin/hosty`
- the root user's `crontab`

CI runs static POSIX-shell checks plus functional smoke tests on Ubuntu, Alpine Linux with BusyBox `ash`, macOS, FreeBSD, and OpenBSD.

## Development

Before submitting changes, run the same checks used by CI:

```sh
# Format
shfmt -i 4 -ci -sr -w hosty.sh install.sh ci/*.sh

# POSIX-oriented lint and syntax checks
shellcheck --shell=sh hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/check-sources.sh
dash -n hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/check-sources.sh

# Offline functional tests; requires root or passwordless sudo/doas
./ci/smoke.sh

# Optional network and production-install checks
RUN_NETWORK=1 RUN_PRODUCTION_INSTALL=1 ./ci/smoke.sh

# Optional source URL health check
./ci/check-sources.sh
```

`HOSTY_URL` lets installer tests use an HTTPS URL, a `file://` URL, or a local path. Plain HTTP and other URL schemes are rejected.
