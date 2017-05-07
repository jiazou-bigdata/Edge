#!/bin/bash

# Search github, scrape for removed keys in commits

# colors for display
NOCOLOR='\033[0m'
red() { CRED='\033[0;31m'; echo -e ${CRED}$@${NOCOLOR}; }
blue() { CBLUE='\033[0;34m'; echo -e ${CBLUE}$@${NOCOLOR}; }
green() { CGREEN='\033[0;32m'; echo -e ${CGREEN}$@${NOCOLOR}; }

up() {
    printf "\033[$1A"
    for i in `seq $1`; do
	echo -e "\033[K"
    done
    printf "\033[$1A"
}

search_term="removed+private+key"

get_commits() {
    search=$(curl -s "https://github.com/search?q=$search_term&type=Commits")
    links=$(echo "$search" | grep "Browse the repository at this point in the history")
    repos=$(echo "$links" | sed 's/.*href="\(.*\)" aria.*/\1/p' | uniq)
    echo "[+] Found" $(echo "$repos" | wc -l) "project(s)"
}

get_files() {
    for link in $repos; do
	name=$(echo $link | sed -ne 's:/\(.*\)/tree/.*:\1:p')
	commit=$(echo $link | sed -n 's:.*tree/\(.*\):\1:p')
	cd $dirr
	rm -fr tmp/curr	
	cd tmp
	blue "[*] Cloning $name..."
	git clone https://github.com/$name curr &>/dev/null
	# If this fail then skip all the next stuff
	if [ $? = 0 ]; then
	cd curr

	# Make sure the commit is still there
	git cat-file $commit~1 -t &>/dev/null
	retval=$?
	if [ $retval != 0 ]; then
	    up 1
	    red "[$name] Error commit doesnt exist $commit~1"
	    cd ../../
	    rm -fr tmp/curr
	    continue
	else
	    up 1
	    green "[$name] Commit exists $commit~1"
	fi
	
	# Get the files that have changed
	files=$(git diff "$commit~1" $commit --name-only )
	num_fils=$(echo "$files" | wc -l)
	
        # Checkout the commit before the change
	git checkout $commit~1 &>/dev/null
	if [ $? != 0 ]; then
	    up 1
	    red "[$name] Error cannot checkout $commit~1"
	    continue
	else
	    up 1
	    green "[$name] Checked out $commit~1"
	fi
	
	good_files=0
	for f in $files; do
	    # Make sure the file is ASCII
	    isascii="$(file $f | grep -e '(ASCII|TEXT'))"
	    if [ "$isascii" != "" ]; then 
		# Get the commit difference
		change=$(git show "$commit~1":$f)
		# Check if this contains a key
		if [ "$(echo $change | grep 'PRIVATE KEY')" != "" ]; then
		    good_files=$(($good_files +1))
		    # Make the output fold and make the filename
		    mkdir -p $dirr/found
		    fil=$(echo $f | sed 's=.*/==' )
		    output_folder="$dirr/found/$(echo $name| cut -d'/' -f2)-$fil"
		    # Save the file that has potential
		    git show "$commit~1":$f >> "$output_folder"
		fi
	    else
		:
		#echo "[!] Non-text $f $(file $f)"
	    fi
	done

	# Print the status
	up 1
	if [ $good_files != 0 ]; then
	    green "[$name] $good_files/$num_fils files have potential"
	else
	    echo "[$name] $good_files/$num_fils files have potential"
	fi

	else
	    up 1
	    red "[!] Error cloning $name"
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

echo "[*] Found $(ls $dirr/found | wc -w) files"
