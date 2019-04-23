hosty
=====

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrolince/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrolince/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrolince/hosty.svg)
![GitHub stars](https://img.shields.io/github/stars/astrolince/hosty.svg?label=Star&style=social)
![GitHub watchers](https://img.shields.io/github/watchers/astrolince/hosty.svg?label=Watch&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrolince/hosty.svg?label=Fork&style=social)](https://github.com/astrolince/hosty)

System-wide ad blocker for Linux.

It works by downloading a list of hosts files dedicated to blocking ads and malware and unifying them with the hosts file of your system (maintaining the existing rules).

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Installation

### Requirements
* wget
* curl
* awk
* sed
* 7z
* zip

### Install the requirements

* **Ubuntu/Mint/Elementary/Pop/Debian:**  
`$ sudo apt install wget curl gawk sed p7zip-full gzip`

* **Arch/Manjaro/Antergos:**  
`$ sudo pacman -S wget curl gawk sed p7zip gzip`

* **Fedora/RHEL/CentOS:**  
`$ sudo dnf install wget curl gawk sed p7zip p7zip-plugins gzip`

### Install hosty

Just run:

`$ curl -L git.io/hosty | sh`

## Run hosty

Enable system-wide ad blocking with:

`$ sudo hosty`

You probably want to run it periodically to update the ads list.

## Automatic run

You can create a `hosty` file in `/etc/cron.daily`, `/etc/cron.weekly` or `/etc/cron.monthly`

Hosty has an option for doing that:

`$ sudo hosty --autorun`

or, if you want to skip unbreak filters:

`$ sudo hosty --autorun --all`

Hosty will ask how often you want to execute it.

## Whitelist

You can include exceptions editing the file `/etc/hosts.whitelist` (with root permissions) or `~/.hosty.whitelist`, one domain name per line.

Besides, hosty applies an internal whitelist based on Brave and uBlock Origin unbreak filters. If you only want to use your custom whitelist and avoid the internal whitelist run:

`$ sudo hosty --all`

## Blacklist

Hosty will keep your hosts file modifications if you don't write them below the indicated line, but you can also use a blacklist.

Add the domains to block editing the file `/etc/hosts.blacklist` (with root permissions) or `~/.hosty.blacklist`, one domain name per line.

## Add hosts files sources

If you want to feed hosty with additional sources you just have to create a text file in `/etc/hosty` (with root permissions) or `~/.hosty` and write in it one url per line.

## Restore your original hosts file

If you want to disable hosty ad blocking:

`$ sudo hosty --restore`

## Read the modified hosts without modifying your system

You can debug what hosty will do to your system with:

`$ hosty --debug`

or

`$ hosty --debug --all`

## Uninstalling hosty

If you don't use it anymore:

`$ sudo rm /usr/local/bin/hosty`
