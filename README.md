# Cfx server Database Backup resource

For those who want to have a resource handle database backups, this will run within your FiveM or RedM server and create backups of your database.

## Usage

Currently this script only has a server console command to generate a backup within the `backups/` directory, more will come.

```bash
# file name without the extension, the script will add it itself
# if no filename is passed it'll generate one based on current date & time
backup_database [backup_filename]
```

## Config fields

* `QuerySize`:
  * Defines the size of each query batch within the system that obtains the data from the tables
  * Default: `100`
* `ExcludedTables`:
  * List the tables that shouldn't be backed up by the script
  * Default: `nil` - Accepts: `string[] | false | nil`
* `ExclusiveTables`:
  * List the only tables that should be backed up, all others will be ignored 
  * Default: `nil` - Accepts: `string[] | false | nil`
