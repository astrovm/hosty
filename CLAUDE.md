# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hosty is a system-wide ad blocker for Linux/Unix/BSD/Mac systems that works by modifying the `/etc/hosts` file to block malicious domains. The project consists of shell scripts that download blocklists and whitelists from various sources, process them, and update the system hosts file.

## Key Commands

### Installation
- `curl -L https://4st.li/hosty/install.sh | sh` - Install hosty
- `sudo hosty` - Run hosty to update hosts file with ad blocking domains

### Main Operations
- `sudo hosty` - Update hosts file with latest blocklist
- `sudo hosty -r` or `sudo hosty --restore` - Restore original hosts file
- `sudo hosty -d` or `sudo hosty --debug` - Run in debug mode without system changes
- `sudo hosty -a` or `sudo hosty --autorun` - Configure automatic periodic updates
- `sudo hosty -i` or `sudo hosty --ignore-default-sources` - Use only custom sources
- `sudo hosty -u` or `sudo hosty --uninstall` - Uninstall hosty

### Testing
- No formal test suite exists. Testing is done by:
  - Running `sudo hosty -d` to see what changes would be made
  - Verifying hosts file contents after running hosty
  - Testing website blocking functionality

## Architecture

### Core Components

1. **hosty.sh** - Main script that handles all operations:
   - Command line argument parsing using getoptions library
   - Dependency checking (curl, awk, head, cat, mktemp, sort, grep)
   - Download and processing of blocklist/whitelist sources
   - Hosts file manipulation and backup/restore functionality
   - Cron job configuration for automatic updates

2. **install.sh** - Installation script that:
   - Downloads and installs hosty.sh to `/usr/local/bin/hosty`
   - Sets proper permissions
   - Optionally configures automatic updates

3. **updater.sh** (deprecated) - Legacy updater with GPG signature verification

4. **lists/** directory contains default sources:
   - `blacklist` - Local domains to block (currently empty/minimal)
   - `whitelist` - Local domains to allow (contains essential domains)
   - `blacklist.sources` - URLs of remote blocklists
   - `whitelist.sources` - URLs of remote whitelists

### Data Flow

1. Script downloads sources from URLs in `.sources` files
2. Processes downloaded content to extract valid domain names using awk
3. Applies whitelist filtering to remove allowed domains
4. Generates final hosts file with format: `0.0.0.0 blocked-domain.com`
5. Preserves original hosts file content above the hosty-generated section

### Configuration Files

User configurations are stored in `/etc/hosty/`:
- `/etc/hosty/blacklist` - Custom domains to block
- `/etc/hosty/whitelist` - Custom domains to allow
- `/etc/hosty/blacklist.sources` - Custom blocklist URLs
- `/etc/hosty/whitelist.sources` - Custom whitelist URLs

### Key Variables and Constants

- `BLOCK_IP="0.0.0.0"` - IP address used to redirect blocked domains
- `INPUT_HOSTS="/etc/hosts"` - Source hosts file
- `OUTPUT_HOSTS="/etc/hosts"` - Target hosts file
- Default sources hosted at `https://4st.li/hosty/lists/`

### Domain Processing Logic

The `extractDomains()` function in `hosty.sh:391-417` handles:
- Filtering lines that start with letters/numbers/colons
- Removing comments (everything after #)
- Converting non-domain characters to newlines
- Validating domains (must contain dot and letter)
- Removing invalid patterns (starting/ending with dot/hyphen)
- Deduplication and sorting

## Development Notes

- All scripts use POSIX shell (`#!/bin/sh`) for maximum compatibility
- Error handling uses `set -euf` for strict mode
- Extensive use of temporary files for processing
- No build system - scripts are used directly
- GPG signature verification implemented for security (though updater.sh is deprecated)