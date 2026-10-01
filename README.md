# hosty

[![GitHub last commit](https://img.shields.io/github/last-commit/astrovm/hosty.svg)](https://github.com/astrovm/hosty)
[![GitHub license](https://img.shields.io/github/license/astrovm/hosty.svg)](https://github.com/astrovm/hosty)

**Block ads, trackers and malware on your whole system.**

Hosty downloads blocklists, adds your own rules and updates `/etc/hosts`, keeping the entries already there. It runs on Linux, macOS and BSD.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## ⬇️ Install

```sh
curl -fsSL https://4st.li/hosty/install.sh | sh
```

The installer checks Hosty, puts it at `/usr/local/bin/hosty` and offers automatic updates. It runs as root or uses `sudo`, falling back to `doas`. Without a terminal, it skips the automatic-update question.

Hosty needs a POSIX `/bin/sh`, `curl`, `awk` and common Unix tools, which most systems already have.

<details>
<summary><b>Missing something?</b></summary>

Hosty uses `cat`, `chmod`, `cp`, `date`, `dirname`, `grep`, `head`, `id`, `mkdir`, `mktemp`, `mv`, `rm` and `sort`. `crontab` is optional, for automatic updates, and so are `sudo` or `doas`, for running from a non-root account.

| Platform | Command |
| --- | --- |
| Debian, Ubuntu, Mint, Pop!_OS | `sudo apt install curl mawk cron` |
| Arch Linux, Manjaro, EndeavourOS | `sudo pacman -S --needed curl gawk cronie` |
| Fedora, RHEL, Rocky Linux | `sudo dnf install curl gawk cronie` |
| Alpine Linux | `apk add curl` (`cronie` is optional) |
| macOS | Nothing extra, normally |
| FreeBSD | `pkg install curl` |
| OpenBSD | `pkg_add curl` |

</details>

## 🚀 Use

| Command | What it does |
| --- | --- |
| `sudo hosty` | Updates the hosts file |
| `sudo hosty --autorun` | Updates automatically: `daily`, `weekly`, `monthly` or `never` |
| `sudo hosty --restore` | Puts the original hosts file back |
| `sudo hosty --uninstall` | Removes Hosty. Restore first to stop blocking too |
| `hosty --help` | Lists every command. `--version` shows the installed one |

Use `doas` instead of `sudo` if you prefer. Commands that change system files need root.

## What it blocks

- **Ads, tracking, spyware and malware**, and other privacy threats.
- **Not** political censorship, or categories like pornography or gambling.
- **Your entries stay.** Hosty never discards what's already in `/etc/hosts`.

## Your own rules

Optional files in `/etc/hosty`:

| File | Purpose |
| --- | --- |
| `blacklist` | Domains to block |
| `whitelist` | Domains to allow |
| `blacklist.sources` | Blocklist URLs |
| `whitelist.sources` | Allowlist URLs |

Put one domain or URL per line:

```text
example.com
https://example.com/hosts.txt
```

Sources can be plain domains or hosts-format lists. Browser filter rules (ABP, uBlock Origin, AdGuard) don't work.

To use only your own sources and rules, run `sudo hosty --ignore-default-sources`.

## 🛠️ Handy commands

| Command | What it does |
| --- | --- |
| `hosty --lookup example.com example.org` | Shows which lists contain a domain |
| `hosty --check-whitelists` | Shows which whitelist entries override a blocklist |
| `sudo hosty --clean-whitelists` | Removes unused whitelist entries and sources. Stops without changes if blocklist data is incomplete |
| `hosty --debug` | Builds the hosts file in a temporary place and prints its path, without changing anything |

Only `--clean-whitelists` needs root.

## Works everywhere

Hosty uses portable POSIX `sh`, with no Bash or GNU-only features. Every pull request is tested on Ubuntu, Alpine Linux with BusyBox `ash`, macOS and OpenBSD.

<details>
<summary><b>Development</b></summary>

Before sending changes, run the same checks as CI:

```sh
# Format
shfmt -i 4 -ci -sr -w hosty.sh install.sh ci/*.sh ci/smoke-core

# POSIX-oriented lint and syntax checks
shellcheck --shell=sh hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/smoke-core ci/check-sources.sh ci/coverage.sh ci/test-coverage.sh ci/test-hosts-write.sh
for script in hosty.sh install.sh ci/lib.sh ci/smoke.sh ci/smoke-core ci/check-sources.sh ci/coverage.sh ci/test-coverage.sh ci/test-hosts-write.sh; do
    dash -n "$script"
done

# Coverage report and hosts-file writer tests; no root needed
./ci/test-coverage.sh
./ci/test-hosts-write.sh

# Offline functional tests; requires root or passwordless sudo/doas
./ci/smoke.sh

# Line coverage of the offline suite; must stay at 100%
# Requires root, kcov, bash, and python3
sudo ./ci/coverage.sh

# Optional network and production-install checks
RUN_NETWORK=1 RUN_PRODUCTION_INSTALL=1 ./ci/smoke.sh

# Optional source URL health check
./ci/check-sources.sh
```

The smoke suite snapshots and restores `/etc/hosts`, `/etc/hosty`, `/usr/local/bin/hosty`, the root user's crontab, and legacy Hosty scripts under `/etc/cron.daily`, `/etc/cron.weekly`, and `/etc/cron.monthly`, including when a test fails.

`HOSTY_URL` lets installer tests use an HTTPS URL, a `file://` URL, or a local path. Plain HTTP and other URL schemes are rejected.

</details>
