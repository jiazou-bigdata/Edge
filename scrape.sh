#!/bin/bash

# Search github, scrape for removed keys in commits
search_term="removed+private+key"

get_commits() {
    search=$(curl -s "https://github.com/search?q=$search_term&type=Commits")
    links=$(echo "$search" | grep "Browse the repository at this point in the history")
    repos=$(echo "$links" | sed 's/.*href="\(.*\)" aria.*/\1/p' | uniq)
}

get_files() {
    for link in $repos; do
	name=$(echo $link | sed -ne 's:/\(.*\)/tree/.*:\1:p')
	commit=$(echo $link | sed -n 's:.*tree/\(.*\):\1:p')
	cd tmp
	git clone https://github.com/$name curr &>/dev/null
	if [ $? != 0 ]; then
	    echo "[!] Error!!"
	    echo "$out"
	    continue
	fi
	cd curr
	git checkout "$commit~1"
	if [ $? != 0 ]; then
	    echo "[!] Error checking out $name"
	    rm -fr tmp/curr
	    exit
	fi
	#files=$(git diff "$commit~1" $commit --name-only )
	grep -l 'PRIVATE KEY' -r ./
	#echo $files
	#| sed -e '/BEGIN/,/END PRIVATE/!d')
	#key=$(echo $diff | sed 's:\n:\\n:p' |\
	#grep -o --color "BEGIN PRIVATE KEY.*END PRIVATE KEY")
	cd ../../
	#echo $diff
	rm -fr tmp/curr
    done
}

init() {
    # Create the temp directory if it doesnt exist
    [ ! -d "tmp" ] && mkdir tmp
}

init
get_commits
get_files
