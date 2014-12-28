#!/bin/bash

echo

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

# Perform work in temporary files
temphosts1=$(mktemp)
temphosts2=$(mktemp)
temphosts3=$(mktemp)
tempwhitelist=$(mktemp)
tempwhitelistd=$(mktemp -d)

# Obtain various hosts files and merge into one
echo "Downloading ad-blocking hosts files..."

adaway=$(curl -s --head -w %{http_code} http://adaway.org/hosts.txt -o /dev/null)
winhelp2002=$(curl -s --head -w %{http_code} http://winhelp2002.mvps.org/hosts.txt -o /dev/null)
hostsfile=$(curl -s --head -w %{http_code} http://hosts-file.net/ad_servers.asp -o /dev/null)
someonewhocares=$(curl -s --head -w %{http_code} http://someonewhocares.org/hosts/hosts -o /dev/null)
pgl=$(curl -s --head -w %{http_code} "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" -o /dev/null)
publicidadchile=$(curl -s --head -w %{http_code} https://raw.githubusercontent.com/jorgicio/publicidad-chile/master/hosts.txt -o /dev/null)

if [[ $adaway -lt 400 && $adaway -gt 000 ]]
then
  wget -nv -O - http://adaway.org/hosts.txt >> $temphosts1
fi
if [[ $winhelp2002 -lt 400 && $winhelp2002 -gt 000 ]]
then
  wget -nv -O - http://winhelp2002.mvps.org/hosts.txt >> $temphosts1
fi
if [[ $hostsfile -lt 400 && $hostsfile -gt 000 ]]
then
  wget -nv -O - http://hosts-file.net/ad_servers.asp >> $temphosts1
fi
if [[ $someonewhocares -lt 400 && $someonewhocares -gt 000 ]]
then
  wget -nv -O - http://someonewhocares.org/hosts/hosts >> $temphosts1
fi
if [[ $pgl -lt 400 && $pgl -gt 000 ]]
then
  wget -nv -O - "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" >> $temphosts1
fi
if [[ $publicidadchile -lt 400 && $publicidadchile -gt 000 ]]
then
  wget -nv -O - https://raw.githubusercontent.com/jorgicio/publicidad-chile/master/hosts.txt >> $temphosts1
fi

# Do some work on the file:
# 1. Remove MS-DOS carriage returns
# 2. Delete all lines that don't begin with 127.0.0.1 or 0.0.0.0
# 3. Delete any lines containing the word localhost because we'll obtain that from the original hosts file
# 4. Replace 127.0.0.1 with 0.0.0.0 because then we don't have to wait for the resolver to fail
# 5. Scrunch extraneous spaces separating address from name into a single tab
# 6. Delete any comments on lines
# 7. Clean up leftover trailing blanks
# Pass all this through sort with the unique flag to remove duplicates and save the result

echo
echo "Parsing, cleaning, de-duplicating, sorting..."
sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e '/^127.0.0.1\|0.0.0.0/!d' -e '/da.feedsportal.com/d' -e '/pixel.everesttech.net/d' -e '/www.googleadservices.com/d' -e '/maxcdn.com/d' -e '/static.addtoany.com/d' -e '/addthis.com/d' -e '/googletagmanager.com/d' -e '/addthiscdn.com/d' -e '/sharethis.com/d' -e '/twitter.com/d' -e '/pinterest.com/d' -e '/ojrq.net/d' -e '/rpxnow.com/d' -e '/google-analytics.com/d' -e '/shorte.st/d' -e '/adf.ly/d' -e '/www.linkbucks.com/d' -e '/static.linkbucks.com/d' -e '/localhost/d' -e 's/127.0.0.1/0.0.0.0/' -e 's/#.*$//' -e '/^$/d' -e '/./!d' < $temphosts1 | sort > $temphosts2

# Applies whitelist
echo
echo "Applying whitelist..."

wlc1=0
wlc2=1

cat $temphosts2 > $tempwhitelistd/1
sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e 's/127.0.0.1/0.0.0.0/' -e 's/#.*$//' -e '/^$/d' -e '/./!d' < /etc/hosts.whitelist | sort | uniq > $tempwhitelist

cat $tempwhitelist |
{
  while read -r line
  do
    wlc1=$((wlc1 + 1))
    wlc2=$((wlc2 + 1))
    echo "Deleting all lines that contain '"$line"'..."
    sed -e "/$line/d" $tempwhitelistd/$wlc1 > $tempwhitelistd/$wlc2
  done
  sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e '/^127.0.0.1\|0.0.0.0/!d' -e 's/#.*$//' -e '/^$/d' -e '/./!d' < $tempwhitelistd/$wlc2 | sort > $tempwhitelist ;
}

# Combine system hosts with adblocks
echo
echo "Merging with original system hosts..."
echo -e "\n# Ad blocking hosts generated "$(date) | cat /etc/hosts.original - $tempwhitelist > $temphosts3
sudo bash -c "sed -e 's/\r//' -e 's/[[:space:]]\+/ /g' -e 's/[ \t]*$//' -e '/^$/d' -e '/./!d' < $temphosts3 | uniq > /etc/hosts"

# Clean up temp files and reminds the user how to restore the original hosts file
echo
echo "Cleaning up..."
rm $temphosts1 $temphosts2 $temphosts3 $tempwhitelist
rm -R $tempwhitelistd
echo
echo "Done."
echo
echo "You can always restore your original hosts file with this command:"
echo "  sudo cp /etc/hosts.original /etc/hosts"
echo "So don't delete that file! (It's saved read-only for your protection.)"
echo
