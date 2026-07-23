# hosty

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrovm/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrovm/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrovm/hosty.svg)
![GitHub watchers](https://img.shields.io/github/watchers/astrovm/hosty.svg?label=Watch&style=social)
![GitHub stars](https://img.shields.io/github/stars/astrovm/hosty.svg?label=Star&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrovm/hosty.svg?label=Fork&style=social)](https://github.com/astrovm/hosty)

Hosty is a system-wide hosts-file blocker for Unix-like operating systems. It is written in portable POSIX `sh` and supports Linux distributions, Alpine Linux, macOS, FreeBSD, and OpenBSD without requiring Bash or GNU-only tools.

Hosty downloads domain lists, combines them with your custom rules, applies your whitelist, and writes the result to `/etc/hosts` without discarding your existing entries.

The default lists focus on ads, tracking, spyware, malware, and other privacy threats. They intentionally avoid political censorship and paternalistic categories such as pornography or gambling.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Requirements

Required:

- a POSIX-compatible `/bin/sh`
- `curl`
- `awk`
- common Unix utilities: `cat`, `chmod`, `dirname`, `grep`, `head`, `mktemp`, `mv`, `rm`, and `sort`

Optional:

- `crontab`, for automatic updates
- `sudo` or `doas`, when installing or running Hosty from a non-root account

Most required utilities are already included in the base system. Install the missing packages for your platform:

| Platform | Command |
|---|---|
| Debian, Ubuntu, Mint, Pop!_OS | `sudo apt install curl mawk cron` |
| Arch Linux, Manjaro, EndeavourOS | `sudo pacman -S --needed curl gawk cronie` |
| Fedora, RHEL, Rocky Linux | `sudo dnf install curl gawk cronie` |
| Alpine Linux | `apk add curl` (`cronie` is optional) |
| macOS | No additional package is normally required |
| FreeBSD | `pkg install curl` |
| OpenBSD | `pkg_add curl` |

Run package-manager commands as root. Prefix them with `sudo` or `doas` when your system is configured that way.

## Install

```sh
curl -fsSL https://4st.li/hosty/install.sh | sh
```

The installer:

- uses the current account when it is already root
- otherwise uses `sudo`, falling back to `doas`
- downloads and validates Hosty before replacing an existing installation
- installs the executable at `/usr/local/bin/hosty`
- optionally configures automatic updates when a terminal and `crontab` are available

To install non-interactively, run the command above without a terminal. The installer skips the automatic-update prompt; configure it later with `hosty -a` as root.

## Usage

Hosty must run as root when it changes the system. Use whichever privilege mechanism your system provides:

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

Hosty accepts hosts-style files, plain domain lists, and common ABP/uBlock Origin/Brave/AdGuard-style filter lists. It extracts every valid-looking domain from uncommented content, so review third-party sources carefully. Whitelisting an unfamiliar filter source is safer than blacklisting it.

Run only with custom sources and local rules:

```sh
sudo hosty --ignore-default-sources
```

Configure automatic updates in the same mode:

```sh
sudo hosty --autorun --ignore-default-sources
```

## Portability

The scripts use POSIX shell syntax and portable `awk` expressions. They do not depend on Bash, GNU `sed`, GNU `awk`, systemd, or Linux-specific APIs.

Hosty uses `/etc/hosts`, `/etc/hosty`, `/usr/local/bin`, and the root user's crontab. These locations and interfaces are available on the supported Linux, Alpine, macOS, FreeBSD, and OpenBSD systems.

## Development

Before submitting changes, run the same checks used by CI:

```sh
# Format
shfmt -i 4 -ci -sr -w hosty.sh install.sh ci/*.sh

# Lint and syntax
shfmt -i 4 -ci -sr -d hosty.sh install.sh ci/*.sh
shellcheck hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/check-sources.sh
sh -n hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/check-sources.sh

# Offline functional tests; requires root or passwordless privilege elevation
./ci/smoke.sh

# Optional network and production-install checks
RUN_NETWORK=1 RUN_PRODUCTION_INSTALL=1 ./ci/smoke.sh

# Optional source URL health check
./ci/check-sources.sh
```

`HOSTY_URL` lets installer tests use an HTTPS URL, a `file://` URL, or a local path. Plain HTTP and other URL schemes are rejected.
