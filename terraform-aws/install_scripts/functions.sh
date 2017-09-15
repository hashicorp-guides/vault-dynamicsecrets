#!/usr/bin/env bash

_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROGDIR=${PROGDIR:-"/usr/bin"}

# Set up config
export CONFIG=$(cat ${_DIR}/config.json)

## Log message
function message {
	if [ "$2" == "err" ]; then
		COLOR='\033[00;31m'
	else
		COLOR='\033[00;32m'
	fi
	echo -e "${COLOR}[${SCRIPTNAME:-HASHISCRIPT}] ${1}\033[0m"
}
export -f message

## Install application
function ensure_installed { # $1 = name, $2 = url, $3 = base dir (for zip file) or package name (for dmg)
	if ! which $1 &> /dev/null; then
		if [ -z "$2" ]; then
			message "Installing $1 via yum..."
			yum install $1 -y
		else
			message "Installing $1 from URL..."
			curl -sOL $2
			FILENAME=$(echo $2 | rev | cut -d/ -f1 | rev)
			if [ ${FILENAME: -4} == ".zip" ]; then
				message "Unzipping archive..."
				unzip -o $FILENAME -d $PROGDIR &> /dev/null
				if [ -n "$3" ]; then
					mv $PROGDIR/$3/* $PROGDIR
				fi
				rm -f $FILENAME
			elif [ ${FILENAME: -4} == ".dmg" ]; then     # This is for OS X only
				message "Installing package from dmg..."
				mountdir=$(hdiutil attach $FILENAME | awk -F' ' '{ print $3 }' | tail -n 1)
				installer -pkg $mountdir/$3 -target /
				hdiutil detach /Volumes/Vagrant || true  # We don't want to exit the script if unmount fails - user can do it later
				rm -f $FILENAME || true                  # Same thing here
			else
				chmod +x $FILENAME
				mv $FILENAME $PROGDIR/$1
			fi
			message "Done."
		fi
	else
		message "Program $1 already installed. Skipping..."
	fi
}
export -f ensure_installed

## Uninstall application
function ensure_uninstalled {
	if which $1 &> /dev/null; then
		rm -f $(which $1)
	fi
}

## Install JQ and unzip for the rest of this script to use
ensure_installed "jq" "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64"
ensure_installed "unzip"
ensure_installed "templater.sh" "https://github.com/lavoiesl/bash-templater/archive/master.zip" "bash-templater-master"

## Get config data
function config {
	echo $(echo $CONFIG | jq -r "$1")
}
export -f config

## Set up JSON config for a hashicorp tool
function hashiconfig {
	message "Writing Config..."
	mkdir -p /etc/$1
	rm -f /etc/$1/config.json
	echo $CONFIG | jq -r ".${1}.${2}" > /etc/$1/config.json
}

## Install Hashicorp Service
function hashiservice {
	message "Installing Service..."

	# Set up template vars
	NAME=$1
	CMD=$(config ".${1}.command")
	WORKINGDIR=$(config ".${1}.working_dir")

	# Create working directory
	mkdir -p $WORKINGDIR

	# SystemV systems - use chkconfig
	if pidof /sbin/init &> /dev/null; then
		srvfile="/etc/init.d/$1"
		rm -f $srvfile
		NAME=$NAME \
			CMD=$CMD \
			WORKINGDIR=$WORKINGDIR \
			templater.sh ${_DIR}/sysvinit.sh > $srvfile
		chmod +x $srvfile
		chkconfig --add $1
	fi

	# Systemd systems - use systemctl
	if pidof systemd &> /dev/null; then
		srvfile="/etc/systemd/system/$1.service"
		rm -f $srvfile
		NAME=$NAME \
			CMD=$CMD \
			WORKINGDIR=$WORKINGDIR \
			templater.sh ${_DIR}/systemd.service > $srvfile
		systemctl enable $1.service
	fi

}
export -f hashiservice
