hosty
=====

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrolince/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrolince/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrolince/hosty.svg)
![GitHub watchers](https://img.shields.io/github/watchers/astrolince/hosty.svg?label=Watch&style=social)
![GitHub stars](https://img.shields.io/github/stars/astrolince/hosty.svg?label=Star&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrolince/hosty.svg?label=Fork&style=social)](https://github.com/astrolince/hosty)

System-wide ad blocker for Linux.

Hosty aims to block annoying things designed to steal time like ads, dangerous software such as spyware and things that harms user privacy. By default it works by downloading a predefined list of domains to block and adding them to the hosts file of your system (keeping the existing rules intact).

In the predefined list we don't accept political censorship or paternalistic goals like blocking porn or gambling, we DON'T accept anything that harms user FREEDOM.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Installation

### Requirements
* curl
* awk
* sed
* 7z
* zip

### Install the requirements

* **Ubuntu/Mint/Elementary/Pop/Debian:**  
`$ sudo apt install curl gawk sed p7zip-full gzip`

* **Arch/Manjaro/Antergos:**  
`$ sudo pacman -S curl gawk sed p7zip gzip`

* **Fedora/RHEL/CentOS:**  
`$ sudo dnf install curl gawk sed p7zip p7zip-plugins gzip`

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

Hosty will ask how often you want to execute it.

## Blacklist

Hosty will keep your hosts file modifications if you don't write them below the indicated line, but you can also use a blacklist.

Add the domains to block editing the file `/etc/hosty/blacklist` (with root permissions), one domain name per line:

```
facebook.com
wwww.facebook.com
```

## Whitelist

You can include exceptions editing the file `/etc/hosty/whitelist` (with root permissions), one domain name per line:

```
astrolince.com
www.astrolince.com
```

## Custom sources

If you want to feed hosty with additional sources from the internet you just have to create a text file in:

`/etc/hosty/blacklist.sources` for files with domains to block

or/and

`/etc/hosty/whitelist.sources` for files with domains to unblock

and write in them one url per line:

`https://www.malwaredomainlist.com/hostslist/hosts.txt`

Hosty will take all domains separated by some symbol, space or new line, so it supports hosts-style files and files with just domains.

ABP, uBlock Origin, Brave and AdGuard files are accepted too, but take in account that ANY not-commented domain will be used, so it's safer to use them in whitelists than in blacklists (a website that you don't want to block can end up blocked if exists in the file).

## Restore your original hosts file

If you want to disable hosty ad blocking:

`$ sudo hosty --restore`

## Read the modified hosts without modifying your system

You can debug what hosty will do to your system with:

`$ hosty --debug`

## Uninstalling hosty

If you don't use it anymore:

`$ sudo rm /usr/local/bin/hosty`
