hosty
=====

[![GitHub code size](https://img.shields.io/github/languages/code-size/astrolince/hosty.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/astrolince/hosty.svg)
![GitHub license](https://img.shields.io/github/license/astrolince/hosty.svg)
![GitHub watchers](https://img.shields.io/github/watchers/astrolince/hosty.svg?label=Watch&style=social)
![GitHub stars](https://img.shields.io/github/stars/astrolince/hosty.svg?label=Star&style=social)
![GitHub forks](https://img.shields.io/github/forks/astrolince/hosty.svg?label=Fork&style=social)](https://github.com/astrolince/hosty)

System-wide ad blocker for Linux/Unix/BSD/Mac.

Hosty aims to block annoying things designed to steal time like ads, dangerous software such as spyware and things that harms user privacy. By default it works by downloading a predefined list of domains to block and adding them to the hosts file of your system (keeping the existing rules intact).

In the predefined list we don't accept political censorship or paternalistic goals like blocking porn or gambling, we don't accept anything that harms user freedom.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Installation

### Requirements
* bash
* curl
* gawk
* gpg/gnupg (optional for automatic hosty version update)
* crontab/cronie (optional for automatic hosts file update)
* 7z/p7zip (optional for .7z sources)
* zcat/gzip (optional for .zip sources)

### Install the requirements

* **Ubuntu/Mint/Elementary/Pop/Debian:**
`$ sudo apt install bash curl gawk gnupg cron p7zip-full gzip`

* **Arch/Manjaro/Endeavour:**
`$ sudo pacman -S --needed bash curl gawk gnupg cronie p7zip gzip`

* **Fedora/RHEL/Rocky Linux:**
`$ sudo dnf install bash curl gawk gnupg2 cronie p7zip p7zip-plugins gzip`

* **Sailfish OS:**
`$ devel-su zypper install p7zip-full gawk gzip gnu-bash`  
`$ devel-su ln -s /usr/bin/gpg2 /usr/bin/gpg`  
Install vixie-cron from openrepos.net: https://openrepos.net/content/ade/vixie-cron  
Install & configure `sudo` in Sailfish to properly use of hosty:  
`$ devel-su pkcon install sudo`  
Add "defaultuser" as "sudoer" using "nano":  
`$ devel-su nano /etc/sudoers`  
Adding at the end of the file:  
`defaultuser ALL=(ALL) ALL`

### Install hosty

Just run:

`$ curl -L git.io/hosty | sh`

The installer will ask you if you want to always run the latest version of hosty code, to achieve this, code updates are downloaded from this repository in each execution. A verification mechanism is included, hosty will make sure automatically that the updates are signed by me.

Still, you may not like to trust me, you can also install hosty without automatic code updates and manually check if updates are available.

You will also be asked if you want to automatically run hosty every so often to update your hosts file with latest domains list.  

### Aditional steps to install hosty in Sailfish OS  

During installation hosty will ask if you want to automatically run hosty from time to time to update your hosts file with the latest list of domains.

We answer the following questions:

    Do you want to always run the latest version of hosty? Y

    Do you want to automatically update your hosts file with latest ads list? n

Once hosty ends its installation, just run again:

`$ curl -L git.io/hosty | sh`

### Extend Ad Blocking to Sailfish OS Android App Support

Add this line to `/var/lib/lxc/aliendalvik/extra_config` (create the file if it doesn't exist):  

`$ sudo nano /var/lib/lxc/aliendalvik/extra_config`  

`lxc.mount.entry = /etc/hosts system/etc/hosts none bind,create=file 0 0`  

## Run hosty

Enable system-wide ad blocking with:

`$ sudo hosty`

You probably want to run it periodically to update your hosts file with latest domains list.

## Automatic run configuration

Hosty can be configured to periodically update your hosts file with:

`$ sudo hosty --autorun`

It will ask how often you want to execute it. A `hosty` file in `/etc/cron.daily`, `/etc/cron.weekly` or `/etc/cron.monthly` will be created.

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

If you want to add additional custom sources from the internet,  create a text file in:

`/etc/hosty/blacklist.sources` for files with domains to block

or/and

`/etc/hosty/whitelist.sources` for files with domains to unblock

and write in them one url per line:

`https://www.malwaredomainlist.com/hostslist/hosts.txt`

Hosty will take all domains separated by some symbol, space or new line, so it supports hosts-style files and files with just domains.

ABP, uBlock Origin, Brave and AdGuard files are accepted too, but take in account that ANY not-commented domain will be used, so it's safer to use them in whitelists than in blacklists (a website that you don't want to block can end up blocked if exists in the file).

You can also run hosty using ONLY your custom sources with:

`$ sudo hosty --ignore-default-sources`

and you can config autorun to run that way too:

`$ sudo hosty --autorun --ignore-default-sources`

Keep in mind that this is an advanced function that we do not recommend using, hosty is designed and tested to be used with the default configuration and in that way we believe that it will give you the best experience.

## Restore your original hosts file

If you want to disable hosty ad blocking:

`$ sudo hosty --restore`

## Read the modified hosts without modifying your system

You can debug what hosty will do to your system with:

`$ hosty --debug`

## Uninstalling hosty

If you don't use it anymore:

`$ sudo hosty --uninstall`

If your want to restore your original hosts file, run that option first.

## License

[MIT License](https://github.com/astrolince/hosty/blob/master/LICENSE)
