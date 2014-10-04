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

# Perform work in temporary files
temphosts1=$(mktemp)
temphosts2=$(mktemp)
temphosts3=$(mktemp)

# Obtain various hosts files and merge into one
echo "Downloading ad-blocking hosts files..."
wget -nv -O - http://adaway.org/hosts.txt >> $temphosts1
wget -nv -O - http://winhelp2002.mvps.org/hosts.txt >> $temphosts1
wget -nv -O - http://hosts-file.net/ad_servers.asp >> $temphosts1
wget -nv -O - http://someonewhocares.org/hosts/hosts >> $temphosts1
wget -nv -O - "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" >> $temphosts1

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
sed -e 's/\r//' -e '/^127.0.0.1\|0.0.0.0/!d' -e '/da.feedsportal.com/d' -e '/localhost/d' -e 's/127.0.0.1/0.0.0.0/' -e 's/ \+/\t/' -e 's/#.*$//' -e 's/[ \t]*$//' < $temphosts1 | sort -u > $temphosts2

# Combine system hosts with adblocks
echo
echo "Merging with original system hosts..."
echo -e "\n# Ad blocking hosts generated "$(date) | cat /etc/hosts.original - $temphosts2 > $temphosts3
sudo bash -c "sed -e '/^$/d' -e '/./!d' $temphosts3 > /etc/hosts"
# Clean up temp files and reminds the user how to restore the original hosts file
echo
echo "Cleaning up..."
rm $temphosts1 $temphosts2 $temphosts3
echo
echo "Done."
echo
echo "You can always restore your original hosts file with this command:"
echo "  sudo cp /etc/hosts.original /etc/hosts"
echo "So don't delete that file! (It's saved read-only for your protection.)"
echo
