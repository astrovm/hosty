# hosty

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrovm/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrovm/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrovm/hosty.svg)
![GitHub watchers](https://img.shields.io/github/watchers/astrovm/hosty.svg?label=Watch&style=social)
![GitHub stars](https://img.shields.io/github/stars/astrovm/hosty.svg?label=Star&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrovm/hosty.svg?label=Fork&style=social)](https://github.com/astrovm/hosty)

System-wide ad blocker for Linux/Unix/BSD/Mac.

Hosty aims to block annoying things designed to steal time like ads, dangerous software such as spyware and things that harms user privacy. By default it works by downloading a predefined list of domains to block and adding them to the hosts file of your system (keeping the existing rules intact).

In the predefined list we don't accept political censorship or paternalistic goals like blocking porn or gambling, we don't accept anything that harms user freedom.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Installation

### Requirements

- curl
- awk
- crontab (optional for automatic hosts file update)

### Install the requirements

- **Ubuntu/Mint/Pop/Debian:**
  `$ sudo apt install curl gawk cron`

- **Arch/Manjaro/Endeavour:**
  `$ sudo pacman -S --needed curl gawk cronie`

- **Fedora/RHEL/Rocky:**
  `$ sudo dnf in curl gawk cronie`

### Install hosty

Just run:

`$ curl -L https://4st.li/hosty/install.sh | sh`

You will be asked if you want to automatically run hosty to update your hosts file with the latest domains list.

## Run hosty

Enable system-wide ad blocking with:

`$ sudo hosty`

You probably want to run it periodically to update your hosts file with latest domains list.

## Automatic run configuration

Hosty can be configured to periodically update your hosts file with:

`$ sudo hosty -a (--autorun)`

It will ask how often you want to execute it and change your crontab.

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
4st.li
www.4st.li
```

## Custom sources

If you want to add additional custom sources from the internet, create a text file in:

`/etc/hosty/blacklist.sources` for files with domains to block

or/and

`/etc/hosty/whitelist.sources` for files with domains to unblock

and write in them one url per line:

`https://www.malwaredomainlist.com/hostslist/hosts.txt`

Hosty will take all domains separated by some symbol, space or new line, so it supports hosts-style files and files with just domains.

ABP, uBlock Origin, Brave and AdGuard files are accepted too, but take in account that ANY not-commented domain will be used, so it's safer to use them in whitelists than in blacklists (a website that you don't want to block can end up blocked if exists in the file).

You can also run hosty using ONLY your custom sources with:

`$ sudo hosty -i (--ignore-default-sources)`

and you can config autorun to run that way too:

`$ sudo hosty -ai (--autorun --ignore-default-sources)`

Keep in mind that this is an advanced function that we do not recommend using, hosty is designed and tested to be used with the default configuration and in that way we believe that it will give you the best experience.

## Restore your original hosts file

If you want to disable hosty ad blocking:

`$ sudo hosty -r (--restore)`

## Read the modified hosts without modifying your system

You can debug what hosty will do to your system with:

`$ hosty -d (--debug)`

## Uninstalling hosty

If you don't use it anymore:

`$ sudo hosty -u (--uninstall)`

If your want to restore your original hosts file, run that option first.
