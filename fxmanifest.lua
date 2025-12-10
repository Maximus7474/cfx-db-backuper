fx_version 'cerulean'
games { 'gta5', 'rdr2' }
server_only 'yes'

version '0.0.0'
author 'Maximus7474'
description 'Basic script to "dump" your database to create backups within fxserver'
repository 'https://github.com/Maximus7474/cfx-db-backuper'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
	'config.lua',
    'modules/*.lua',
}
