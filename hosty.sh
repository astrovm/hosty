#!/bin/bash

# Add ad-blocking hosts files in this array
HOSTS=("http://adaway.org/hosts.txt" "http://winhelp2002.mvps.org/hosts.txt" "http://hosts-file.net/ad_servers.asp" "http://someonewhocares.org/hosts/hosts" "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" "https://raw.githubusercontent.com/jorgicio/publicidad-chile/master/hosts.txt")
# Add AdBlock Plus rules files in this array
RULES=("https://easylist-downloads.adblockplus.org/easylist.txt" "https://data.getadblock.com/filters/adblock_custom.txt" "https://easylist-downloads.adblockplus.org/easyprivacy.txt" "http://abp.mozilla-hispano.org/nauscopio/filtros.txt" "https://easylist-downloads.adblockplus.org/malwaredomains_full.txt")

host=$(mktemp)

if [ "$1" == "--restore" ]; then
	ln=$(sed -n '/^# Ad blocking hosts generated/=' /etc/hosts)
	if [ -z $ln ]; then
		echo "There is nothing to restore"
	else
		let ln-=1
		head -n $ln /etc/hosts > $host
		sudo bash -c "cat $host > /etc/hosts"
		echo "Restore completed"
	fi
	exit 0
fi

# If this is our first run, create a whitelist file and set to read-only for safety
if [ ! -f /etc/hosts.whitelist ]
then
  echo "Creating whitelist file..."
  sudo touch /etc/hosts.whitelist
  sudo chmod 444 /etc/hosts.whitelist
  echo
fi

aux=$(mktemp)
white=$(mktemp)

# Obtain various hosts files and merge into one
echo "Downloading ad-blocking files..."
for i in "${HOSTS[@]}"
do
	wget --no-cache -nv -O $aux $i
	if [ $? != 0 ]; then
		echo "Error downloading $i"
	else
		cat $aux >> $host
	fi
done
# Obtain various AdBlock Plus rules files and merge into one
for i in "${RULES[@]}"
do
	wget --no-cache -nv -O $aux $i
	if [ $? != 0 ]; then
		echo "Error downloading $i"
	else
		awk '/^\|\|[a-z][a-z0-9\-_.]+\.[a-z]+\^$/ {print "0.0.0.0",substr($0,3,length($0)-3)}' $aux >> $host
	fi
done

echo "Parsing, cleaning, de-duplicating..."
sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e '/^127.0.0.1\|0.0.0.0/!d' -e '/da.feedsportal.com/d' -e '/pixel.everesttech.net/d' -e '/www.googleadservices.com/d' -e '/maxcdn.com/d' -e '/static.addtoany.com/d' -e '/addthis.com/d' -e '/googletagmanager.com/d' -e '/addthiscdn.com/d' -e '/sharethis.com/d' -e '/twitter.com/d' -e '/pinterest.com/d' -e '/ojrq.net/d' -e '/rpxnow.com/d' -e '/google-analytics.com/d' -e '/shorte.st/d' -e '/adf.ly/d' -e '/www.linkbucks.com/d' -e '/static.linkbucks.com/d' -e '/localhost/d' -e 's/127.0.0.1/0.0.0.0/' -e 's/#.*$//' -e '/^$/d' -e '/./!d' $host > $aux

echo "Applying whitelist..."
cat /etc/hosts.whitelist > $white
awk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' /etc/hosts.original >> $white
awk 'FNR==NR {a[$1]++} FNR!=NR {if ($0 && !a[$2]++) print $0}' $white $aux > $host

echo "Building /etc/hosts..."
ln=$(sed -n '/^# Ad blocking hosts generated/=' /etc/hosts)
if [ -z $ln ]; then
	cat /etc/hosts > $aux
else
	let ln-=1
	head -n $ln /etc/hosts > $aux
fi
echo "# Ad blocking hosts generated $(date)" >> $aux
cat $host >> $aux
echo "# Don't write below this line. It will be lost if you run hosty again" >> $aux

ln=$(grep -c "0.0.0.0" $aux)

if [ "$1" == "--debug" ]; then
	echo "You can see the results in $aux"
else
	sudo bash -c "cat $aux > /etc/hosts"
fi

echo "Done. $ln websites blocked"
echo "You can always restore your original hosts file with this command:"
echo "    sudo hosty --restore"
