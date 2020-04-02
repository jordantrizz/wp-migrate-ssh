#!/bin/bash

help () {
	echo "Usage: migrate.sh [OPTIONS]...
Migrate WordPress sites using ssh/rsync/wp-cli - Created by j@lmt.ca
	
	Required Options
		-sh		Source IP/Hostname.
		-su		Source User
		-d		Domain Name of site to be migrated
	Optional
        	--debug		Print debug messages
		-sd		Set source directory, defaults to public_html
		-dd		Set destination directory, defaults to public_html
		-tu		Temporary URL, not used if not defined.
"
        exit
}

# -- Parse Command Line Arguments https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --debug)
    debug="1"
    shift # past argument
    ;;
    -sh)
    src_ip="$2"
    shift # past argument
    shift # past value
    ;;
    -su)
    src_user="$2"
    shift # past argument
    shift # past value
    ;;
    -sd)
    src_dir="$2"
    shift # past argument
    shift # past value
    ;;
    -d)
    domain="$2"
    shift # past argument
    shift # past value
    ;;
    -tu)
    temp_url="$2"
    shift # past argument
    shift # past value
    ;;
    -dd)
    dst_dir="$2"
    shift # past argument
    shift # past value
    ;;
#    -extra)
#    DKIM="$2"
#    shift # past argument
#    shift # past value
#    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -n $1 ]]; then
    unknown_options=$1
fi

if [ -z "$src_ip" ] || [ -z "$src_user" ] || [ -z "$domain" ]; then help; fi

if [ -z "$src_dir" ]; then src_dir="public_html"; fi
if [ -z "$dst_dir" ]; then src_dir="public_html"; fi

# Variables
src_db_bkup=$src_user-wp-sql.sql

# Grab the database. Need to fix path issues.
ssh $src_user@$src_ip "/usr/local/sbin/wp --path=$src_dir db export ~/$src_db_bkup"
scp $src_user@$src_ip:~/$src_user-wp-sql.sql .

# Import the database.
wp --path=$dst_dir db reset
wp --path=$dst_dir db import $src_db_bkup
rm $src_db_bkup

# Copy files. Should only show one line progress updated.
rsync -r --progress $src_user@$src_ip:$src_dir/wp-content $dst_dir --exclude cache --exclude "infinitewp/backups" --exclude "uploads/backwpup*"

# Temporary URL
if [ -z "$temp_url" ]; then
	wp --path=$dst_dir plugin install multiple-domain --activate
	wp --path=$dst_dir --format=json option set multiple-domain-domains '{"'$domain'":{"base":null,"lang":null,"protocol":"auto"},"'$temp_url'":{"base":null,"lang":null,"protocol":"auto"}}'
fi

# Install default plugins after migrate
#wp --path=$dst_dir plugin install --activate wp-time-capsule
