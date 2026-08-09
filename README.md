# hosty

[![GitHub last commit](https://img.shields.io/github/last-commit/astrovm/hosty.svg)](https://github.com/astrovm/hosty)
[![GitHub license](https://img.shields.io/github/license/astrovm/hosty.svg)](https://github.com/astrovm/hosty)

Hosty is a system-wide hosts-file blocker for Unix-like operating systems. Its scripts use portable POSIX `sh` syntax and common Unix utilities; CI exercises Ubuntu, Alpine/BusyBox, macOS, and OpenBSD.

It downloads domain lists, combines them with custom rules, applies a whitelist, and updates `/etc/hosts` without discarding existing entries.

The default lists focus on ads, tracking, spyware, malware, and other privacy threats. They intentionally avoid political censorship and paternalistic categories such as pornography or gambling.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Requirements

- a POSIX-compatible `/bin/sh`
- `curl`, `awk`, and common Unix utilities: `cat`, `chmod`, `cp`, `date`, `dirname`, `grep`, `head`, `id`, `mkdir`, `mktemp`, `mv`, `rm`, `sort`, and `tr`
- optional: `crontab` for automatic updates
- optional: `sudo` or `doas` when running Hosty from a non-root account

Most required utilities come with the operating system. Install missing packages with the platform package manager:

| Platform                         | Command                                    |
| -------------------------------- | ------------------------------------------ |
| Debian, Ubuntu, Mint, Pop!_OS    | `sudo apt install curl mawk cron`          |
| Arch Linux, Manjaro, EndeavourOS | `sudo pacman -S --needed curl gawk cronie` |
| Fedora, RHEL, Rocky Linux        | `sudo dnf install curl gawk cronie`        |
| Alpine Linux                     | `apk add curl` (`cronie` is optional)      |
| macOS                            | No additional package is normally required |
| FreeBSD                          | `pkg install curl`                         |
| OpenBSD                          | `pkg_add curl`                             |

## Install

```sh
curl -fsSL https://4st.li/hosty/install.sh | sh
```

The installer validates Hosty, installs it at `/usr/local/bin/hosty`, and can configure automatic updates. It runs directly as root or uses `sudo`, falling back to `doas`. Without a terminal, it skips the automatic-update prompt.

## Usage

Update the hosts file:

```sh
sudo hosty
# or
doas hosty
```

Root privileges are required when Hosty changes system files.

Run `hosty --help` for the complete command reference or `hosty --version` for the installed version.

### Inspect lists

Find which lists contain one or more domains:

```sh
hosty --lookup example.com example.org
```

Audit which whitelist entries override a blacklist:

```sh
hosty --check-whitelists
```

These commands are read-only and do not require root privileges.

Remove inactive whitelist entries and sources:

```sh
sudo hosty --clean-whitelists
```

Cleanup changes writable whitelist files. It stops without changing them if blacklist data is incomplete.

### Automatic updates

```sh
sudo hosty --autorun
```

Choose `daily`, `weekly`, `monthly`, or `never`.

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

Hosty stores optional configuration under `/etc/hosty`:

| File                | Purpose                |
| ------------------- | ---------------------- |
| `blacklist`         | domains to block       |
| `whitelist`         | domains to allow       |
| `blacklist.sources` | block-list source URLs |
| `whitelist.sources` | allow-list source URLs |

Add one domain per line to a domain file:

```text
example.com
www.example.com
```

Add one URL per line to a source file:

```text
https://example.com/hosts.txt
```

Sources may contain plain domains or hosts-style entries. Browser filter syntax such as ABP, uBlock Origin, and AdGuard rules is not supported; use hosts-format lists.

Run only with custom sources and local rules:

```sh
sudo hosty --ignore-default-sources
```

## Portability

The scripts avoid Bash-specific syntax and GNU-only text-processing behavior. They use POSIX shell syntax together with `curl`, `mktemp`, and common Unix utilities available on the supported systems.

Every pull request runs static POSIX-shell checks plus functional smoke tests on Ubuntu, Alpine Linux with BusyBox `ash`, macOS, and OpenBSD.

## Development

Before submitting changes, run the same checks used by CI:

```sh
# Format
shfmt -i 4 -ci -sr -w hosty.sh install.sh ci/*.sh ci/smoke-core

# POSIX-oriented lint and syntax checks
shellcheck --shell=sh hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/smoke-core ci/check-sources.sh
for script in hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/smoke-core ci/check-sources.sh; do
    dash -n "$script"
done

# Offline functional tests; requires root or passwordless sudo/doas
./ci/smoke.sh

# Optional network and production-install checks
RUN_NETWORK=1 RUN_PRODUCTION_INSTALL=1 ./ci/smoke.sh

# Optional source URL health check
./ci/check-sources.sh
```

The smoke suite snapshots and restores `/etc/hosts`, `/etc/hosty`, `/usr/local/bin/hosty`, the root user's crontab, and legacy Hosty scripts under `/etc/cron.daily`, `/etc/cron.weekly`, and `/etc/cron.monthly`, including when a test fails.

`HOSTY_URL` lets installer tests use an HTTPS URL, a `file://` URL, or a local path. Plain HTTP and other URL schemes are rejected.
