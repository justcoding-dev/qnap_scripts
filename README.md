# QNAP Scripts

This is my backup script to backup my important shares from 
my QNAP NAS to an external harddrive or to another NAS.

## Prerequisites

The rsync version that QNAP ships with its OS is rather old, so
it's best to first install entware (https://github.com/Entware/entware/wiki/Install-on-QNAP-NAS)
on the QNAP and then install a recent rsync version:

```
opkg install rsync
```

## Usage

Just run the script to see the usage information:

```
.../qback.sh
```

To make a backup, first setup a _.config_ folder on your backup drive. 
Checkout the usage information and the files in the _config.example_ folder
and create your own _shares_ file in the _.config_ folder.

For example, if your backup drive is mounted as _/share/MyPersonalBackup_:

```
cp -r /path/to/this/repo/config.example /share/MyPersonalBackup/.config
nano /share/MyPersonalBackup/.config
```

Then run the script in superdry mode to get a feeling of what it will do:

```
./qback.sh -dd /share/MyPersonalBackup
```

If you are satisfied with the output (some experience with rsync helps, or
you can paste the logged rsync command to https://explainshell.com), you can try
the normal dry run:

```
./qback.sh -d /share/MyPersonalBackup
```

This will create the needed directories on the backup drive and run rsync in dryrun mode, 
so you can see what will be copied. Don't worry though, it's all fake and nothing is
being written yet.

Finally, to make your backup, run

```
./qback.sh /share/MyPersonalBackup
```

The backup will be written to the folder _store/\_\_cur_ on the backup drive. If
all rsync commands executed successfully, this temporary folder will be renamed 
to a timestamped folder with the date of when the script was run. If the script
is stopped and restarted, it will continue updating the temporary folder, so there
should be not incomplete backups hanging around.

Since the script checks if it's already running, it should be possible to run it regularly from 
a cron job - I have not really tested that though, so please save the logs and check them
regularly.
