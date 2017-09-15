#!/usr/bin/env bash

#####
# Hashicorp tool installation script
#####
#
# This script is used to install hashicorp tools
#
# Parameters can be passed in either via command
# line or via environment variables
# 
# Parameters:
#   $1 | $PROGNAME
#   $2 | $YUMUPDATE
#
#####

## Halt on failed command
set -e
## Debug mode
#set -x

## Set up script prereqs
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTNAME=HASHICONFIG
source "${DIR}/functions.sh"

## Parameter input: if envvar is set use it, otherwise assume CLI params are used
PROGNAME=${PROGNAME:-$(echo "$1" | tr '[:upper:]' '[:lower:]')}
YUMUPDATE=${YUMUPDATE:-$(echo "$2" | tr '[:upper:]' '[:lower:]')}
PROGINDEX=$(echo "$PROGNAME" | cut -d '.' -f2)
PROGNAME=$(echo "$PROGNAME" | cut -d '.' -f1)

[[ -z "$PROGNAME" ]] && { message "No program selected. Exiting." "err"; exit 1; }

## Update local system
if [[ "$YUMUPDATE" == "true" ]]; then
	message "Updating local system, please wait..."
	yum update -y
	message "Done."
fi

## Install application
VERSION=$(config ".$PROGNAME | .version")
ensure_installed "$PROGNAME" "https://releases.hashicorp.com/${PROGNAME}/${VERSION}/${PROGNAME}_${VERSION}_linux_amd64.zip"

## Set up config
hashiconfig $PROGNAME $PROGINDEX

## Install as service
hashiservice $PROGNAME

## Start service
message "Starting $PROGNAME service..."
sleep 1
service $PROGNAME restart

message "Done!"

