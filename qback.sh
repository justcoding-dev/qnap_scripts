#!/bin/bash

### DEBUG: Enable echoing of commands
#set -x

#################################################################
### NAS-to-storage server backup script
###
### Script stores incremental backups in dated directories
###
### Written by Joern Stein <dev@justcoding.de> 2014-2022
#################################################################

# Get timestamp for the log files
currDate=`date +%Y%m%d-%H%M`

shares=""
target=""

config=""

fail=0

# The root directory where all shares are on the NAS
source="/share"

store=""
tmpTarget=""
config=""

### Parameters

# Prepare everything and run rsync in dryrun mode
DRYRUN=""

# Do not make any modifications on the disk at all
SUPERDRY=""

# Delete non-existing files from a previous run from __cur directory
DELETE=""

###


usage() {
cat << EOT

$0 - Backup some directories to a backup path

This script is intended to backup shares on a QNAP server to some external
storage, e.g. an attached disk. On the backup target disk there must be a 
directory called '.config' which holds two files:

	shares  - the list of shares to backup, excluding the leading '/share/'
	exclude - List of files to exclude from the backup

Information about the shares to be backed up is stored in these two files. A new
directory 'store' will be created on the backup disk to store the backed up shares.
All shares will be backed up first to a temporary directory names '__cur' in the
storage area. When the backup has completed successfully, it will be renamed to
the date and time of running the script.

If a shares was backed up in earlier backups, all unchanged files will be hardlinked
against the latest of these backups. A share can also be configured to be mirrored
instead of this incremental backup by setting the 'type' column in the 'shares' 
file to '1' - these mirrored backups are stored in the '_mirror' subdirectory.

Usage:

$0 [ --dryrun | -d | -dd | --superdry | --delete ] BackupPath1 [ BackupPath2 ... ]

	-dd,      	--superdry	Go through the backup process without actually changing anything
	-d,			--dryrun	Make only necessary changes to run 'rsync --dry-run', do not copy data
    --delete           		Add '--delete' option to rsync, removing stuff from __cur directory
	BackupPath				List of one or more directories where backups are stored


Format of 'shares' file:

# share,source,type,subdir
#                     \_ Subdirectory where the share should be backed up to. Must 
						 not be in the list of share names
#               \_______ 0 or "" for incremental backups, 1 or "m" for mirror
#         \_____________ Where to find the original, can be /share or user@host:/path
#   \___________________ Name of the folder to backup# Line format
Media
homes,user@192.168.1.1:
vmail,root@mailserver:/var,1,mail

In this example, inthe backup, there will be folders 'Media', 'homes', 'vmail'. 
If no source path is given, the share will be copied from '/share'.

EOT

}

checkIfRunning() {

	# First check if backup process is running
	PIDFILE="$0.__PID__"

	if [ -f "$PIDFILE" ]
	then
		PID="$(cat ${PIDFILE})"
		PROC=`basename $0`

		echo "Checking PIDFILE $PIDFILE for PID $PID / $PROC"

		if (ps -e -o pid,comm | grep -P "^\s*$PID +$PROC" )
		then
			echo \*\*\* backup.sh script is still running.
			echo `ps -e -o pid,comm | grep "$PROC" | grep -v grep`
	  		exit 1
		fi
	fi

	echo My process: $$
	echo $$ > "${PIDFILE}"

}

backupToDrive() {

	dr=$1
	shift

	echo "=== Backup target: $dr"

 	config="$dr/.config"

	store="$dr/store"

	if [ ! -d "$config" ]
	then
		echo "Configuration directory $config is missing"
		return
	fi

	if [ ! -f "$config/shares" ]
	then
		echo "No shares to backup defined in $config/shares"
		return
	fi

	# Parse each line in the shares file
	input="$config/shares"
	while IFS="," read -r share source type subdir
	do

		if [ -z "$source" ]
		then
			source="/share"
		fi

		case $type in
			1 | m | mirror)
				type="1"
				;;
			*)
				type="0"
				;;
		esac

		# Remove leading and trailing spaces
		share=$(echo "$share" | sed 's:^/*::' | sed 's:/*$::')

		# subdir should be "" or "/path"
		subdir=$(echo "$subdir" | sed 's:^/*::' | sed 's:/*$::')
		[ -n "$subdir" ] && subdir="/$subdir"

		# echo "Share:  $share, Source: $source, type: $type, subdir: $subdir"

		backupShare "$share" "$source" "$type" "$subdir"

	done < <(grep -P -v '^\s*#' "$input")

	if [ $fail -eq 0 ]
	then
		echo "=== Moving temporary target $tmpTarget to $drive/store/$currDate"
		[ -z "$DRYRUN" ] && mv "$tmpTarget" "$drive/store/$currDate"
	fi

}

backupShare() {

	share=$1
	source=$2
	type=$3
	subdir=$4

	# echo backup: $share, Source: $source, type: $type, subdir: $subdir

	if [ -z "$share" ] 
	then
		echo "--- Share '$share' undefined"
		return 1
	fi

	# The source could be a network address (user@host:path)
	# if [ ! -d "$source/$share/" ]
	# then
	# 	echo "ERROR: Share '$source/$share' is not a directory"
	#	return 1
	# fi

	echo "========================================================"
	echo "==  $share"

	if [ -f "$config/exclude" ] 
	then
		excludes="--exclude-from=$config/exclude"
	else
		excludes=""
	fi

	ignorePerms=""
	# "--no-perms --no-owner --no-group --no-times"

	if [ "$type" == "1" ]
	then
		# Mirroring requested
		linkDir=""

		target="$store/_mirror$subdir"

	else
		# Check if a previous backup exists which can be used to link against
		# Bei Sortierung nach Datum:       ls -dtr
		# Sortierung nach Verzeichnidsname: ls -d
		linkDir=`ls -d $store/2*$subdir/$share 2>/dev/null | tail -1 `

		echo "==  Link against: $linkDir"

		[ $n "$linkDir" ] && linkDir="--link-dest=$linkDir/"

		# Create a temporary backup directory if it does not exist yet
		target="$store/__cur$subdir"

	fi

	# echo "==  '$source/$share' -> '$target/$share'"

	# Create a temporary backup directory if it does not exist yet
	[ -d "$target" ] || [ -n "$SUPERDRY" ] || mkdir -p "$target"

	                 echo rsync -vrltD --stats $DRYRUN $DELETE $ignorePerms $excludes $linkDir "$source/$share/" "$target/$share/"
	[ -z "$SUPERDRY" ] && rsync -vrltD --stats $DRYRUN $DELETE $ignorePerms $excludes $linkDir "$source/$share/" "$target/$share/"

  	[ $? -ne 0 ] && fail=1

}

echo "=== Checking if backup is already running"

checkIfRunning

echo "=== Parsing parameters"

drives=""

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

while [ "$1" != "" ]; do


    PARAM=`echo "$1" | awk -F= '{print $1}'`
    VALUE=`echo "$1" | awk -F= '{print $2}'`

#    echo "\$1: '$1', PARAM='$PARAM', VALUE='$VALUE'"

    case $PARAM in
        -h | --help)
     		usage
            	exit 1
		;;

        -dd | --superdry)
            	SUPERDRY="1"
            	DRYRUN="--dry-run"
	    	;;

        -d | --dryrun)
            	DRYRUN="--dry-run"
            	;;

 	--delete)
		DELETE="--delete"
		;;

        *)
	    	if [ -d "$1" ]
	    	then
			dr=$(echo $1 | sed 's:/*$::')

			if [ -z $drives ] 
			then
				drives="$dr"
			else
				drives="${drives}${IFS}${dr}"
			fi
	    	else
			echo "ERROR: Unknown parameter '${1}'"
			usage
			exit 1
	    	fi
            	;;

    esac
    shift
done

# DEBUG
# echo "DRYRUN: '$DRYRUN'"
# echo "SUPERDRY: '$SUPERDRY'"
# echo "DRIVES: '$drives'"

if [ -z "$drives" ]
then
	echo "ERROR: No backup targets specified"
	usage
	exit 1
fi

# Loop through all the backup targets given on the command line
for drive in $drives
do
	backupToDrive $drive
done

IFS=$SAVEIFS

endDate=`date +%Y%m%d-%H%M`
echo === Backup finished $endDate

exit 0
