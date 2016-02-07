#!/bin/bash

# this doesn't actually work but is relatively close to correct
# grep -v "[A-Z]" /usr/share/dict/words | tr '[a-z]' '[A-Z]' > words/words-capitalized
# cat words/words-capitalized words/sowpods.txt > words/all-words
# cat words/all-words | sed -e 's/^ *//g;s/ *$//g' | sed `echo "s/\r//"` | sort | uniq > words/words-full-2


# run with just sowpods
cat words/sowpods.txt | sed -e 's/^ *//g;s/ *$//g' | sed "s/$(printf '\r')\$//" | sort | uniq > words/words-full-2

