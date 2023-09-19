#!/bin/bash -x

#################################################################
### Qback Obsolete Backup Removal script
###
### Checks for backups in /...backuppath.../store/_obsolete 
### and deletes one. Will do nothing if no backups are found 
### or anything looks fishy.
###
### Log is written to log subdirectory in backuppath
###
### Cron:
### */5 * * * * /.../removeObsoleteBackups.sh /...backuppath...
###
### Written by Joern Stein <dev@justcoding.de> Aug 2019
#################################################################

# Check for running removal script first:

pidfile="/tmp/obsoleteBackupRemover.pid"

if [ -z "${1}" ]
then
  echo "No backup target path specified as first parameter"
  exit 0
fi


path="${1}/store/_obsolete"
mask='20*'

if [ ! -d "${path}" ]
then
  echo "Missing path '${path}'" >&2
  exit  1
fi

me=`basename $0`

if [ -e "${pidfile}" ]
then
  pid=`cat ${pidfile}`
  if [ -e /proc/$pid ]
  then
    echo "*** Process still running: "`ps | grep ${pid} | grep -v grep` >&2
    exit 1
  fi
fi

currDate=$(date +%Y%m%d-%H%M)
logfile="${1}/log/${currDate}_backupRemover.log"


# no running script could be identified.

# echo "*** $currDate Checking $path/$mask"
ls -1 $path/$mask >/dev/null 2>&1  || { exit 0; }


echo "***" >> $logfile
echo "*** $me ($$) $currDate" >> $logfile

echo $$ > $pidfile

# Get oldest backup in _obsolete directory

oldBackup=`ls -d $path/$mask  | head -1`

if [ ! -d "$oldBackup" ]
then
  echo "Backup directory $oldBackup does not exist" >&2
  exit 1
fi

# remove oldest backup
echo time rm -rf "$oldBackup" >> $logfile
{ time rm -rf "$oldBackup" ; } 2>&1 >> $logfile

rm $pidfile
echo "*** done" `date +%Y%m%d-%H%M` >> $logfile

echo Remaining backups: $(ls -ld $path/$mask | wc -l) >> $logfile
