#!/bin/bash

# Add ad-blocking hosts files in this array
ARR=("http://adaway.org/hosts.txt" "http://winhelp2002.mvps.org/hosts.txt" "http://hosts-file.net/ad_servers.asp" "http://someonewhocares.org/hosts/hosts" "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" "https://raw.githubusercontent.com/jorgicio/publicidad-chile/master/hosts.txt")

# If this is our first run, save a copy of the system's original hosts file and set to read-only for safety
if [ ! -f /etc/hosts.original ]
then
  echo "Saving copy of system's original hosts file..."
  sudo cp /etc/hosts /etc/hosts.original
  sudo chmod 444 /etc/hosts.original
  echo
fi

# If this is our first run, create a whitelist file and set to read-only for safety
if [ ! -f /etc/hosts.whitelist ]
then
  echo "Creating whitelist file..."
  sudo touch /etc/hosts.whitelist
  sudo chmod 444 /etc/hosts.whitelist
  echo
fi

host=$(mktemp)
aux=$(mktemp)
white=$(mktemp)

# Obtain various hosts files and merge into one
echo "Downloading ad-blocking hosts files..."
for i in "${ARR[@]}"
do
	wget --no-cache -nv -O $aux $i
	if [ $? != 0 ]; then
		echo "Error downloading $i"
	else
		cat $aux >> $host
	fi
done

echo "Parsing, cleaning, de-duplicating..."
sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e '/^127.0.0.1\|0.0.0.0/!d' -e '/da.feedsportal.com/d' -e '/pixel.everesttech.net/d' -e '/www.googleadservices.com/d' -e '/maxcdn.com/d' -e '/static.addtoany.com/d' -e '/addthis.com/d' -e '/googletagmanager.com/d' -e '/addthiscdn.com/d' -e '/sharethis.com/d' -e '/twitter.com/d' -e '/pinterest.com/d' -e '/ojrq.net/d' -e '/rpxnow.com/d' -e '/google-analytics.com/d' -e '/shorte.st/d' -e '/adf.ly/d' -e '/www.linkbucks.com/d' -e '/static.linkbucks.com/d' -e '/localhost/d' -e 's/127.0.0.1/0.0.0.0/' -e 's/#.*$//' -e '/^$/d' -e '/./!d' $host > $aux

echo "Applying whitelist..."
cat /etc/hosts.whitelist > $white
awk '/^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $2}' /etc/hosts.original >> $white
awk 'FNR==NR {a[$1]++} FNR!=NR {if ($0 && !a[$2]++) print $0}' $white $aux > $host

echo "Building /etc/hosts..."
cat /etc/hosts.original > $aux
echo "" >> $aux
echo "# Ad blocking hosts generated $(date)" >> $aux
cat $host >> $aux

sudo bash -c "cat $aux > /etc/hosts"
ln=$(grep -c "0.0.0.0" /etc/hosts)

echo "Done. $ln websites blocked"
echo "You can always restore your original hosts file with this command:"
echo "    sudo cp /etc/hosts.original /etc/hosts"
echo "So don't delete that file! (It's saved read-only for your protection.)"
