# Cfx server Database Backup resource

For those who want to have a resource handle database backups, this will run within your FiveM or RedM server and create backups of your database.

## Usage

Currently this script only has a server console command to generate a backup within the `backups/` directory, more will come.

```bash
# file name without the extension, the script will add it itself
# if no filename is passed it'll generate one based on current date & time
backup_database [backup_filename]
```
