# Repository Guidelines

## Project Structure & Module Organization
- `hosty.sh`: main POSIX shell script. Downloads sources, extracts domains, and writes to `/etc/hosts` (or a temp file in debug mode).
- `install.sh`: installer that places `hosty` in `/usr/local/bin` and optionally configures autorun with `crontab`.
- `updater.sh`: signature-verified wrapper that sourced the latest script. Currently deprecated in favor of direct updates.
- `lists/`: default source URLs and example allow/deny lists (`*.sources`, `blacklist`, `whitelist`).
- `.github/workflows/`: CI for security scan and basic runs on Ubuntu/macOS/Alpine.

## Build, Test, and Development Commands
- Run locally (debug, no root needed): `./hosty.sh -d`
- Run with defaults (writes `/etc/hosts`): `sudo ./hosty.sh`
- Autorun setup: `sudo ./hosty.sh -a` (prompts for schedule)
- Restore originals: `sudo ./hosty.sh -r`
- Install locally: `./install.sh`
- Lint shell scripts: `shellcheck hosty.sh install.sh updater.sh`
- Format consistently: `shfmt -i 4 -ci -sr -w *.sh`

## Coding Style & Naming Conventions
- Shell: POSIX `sh` (avoid bashisms), `set -euf` at top.
- Indentation: 4 spaces; wrap long pipelines for readability.
- Variables: constants in `UPPER_SNAKE`, locals in `lower_snake`; functions in `lowerCamelCase` (e.g., `checkDep`, `downloadFile`).
- Tools: run `shellcheck` and `shfmt` before pushing; prefer standard utilities (`awk`, `sed`, `grep`, `curl`).

## Testing Guidelines
- CI mirrors common paths in `.github/workflows/test.yml` (Ubuntu/macOS/Alpine).
- Smoke tests locally:
  - Debug flow: `./hosty.sh -d`, then `./hosty.sh -di`.
  - Installer prompt flow: `./install.sh` (answer prompts; no changes in debug).
- No unit test framework is used; keep changes small and test flags `-a -i -r -d -u -h -v`.

## Commit & Pull Request Guidelines
- Commits: short, imperative subject (<= 72 chars). Example: `update lists: add phishing sources` or `v1.9.7: refresh domains`.
- PRs: include purpose, key changes, manual test steps, and any impact on `README.md` or `lists/*`.
- Link related issues; add screenshots only when relevant (e.g., installer prompts).

## Security & Configuration Tips
- Network I/O and file writes are explicit; prefer debug mode during development to avoid modifying `/etc/hosts`.
- For list updates, prefer editing `lists/*.sources`; avoid political or paternalistic blocking per project policy.
- Installer and updater use network access; verify integrity when touching update flows and keep URLs centralized.

