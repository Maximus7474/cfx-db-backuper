RegisterCommand('backup_database', function (source, args)
	if source ~= 0 then return end

	local fileName = args[1] or string.format('backup-%s', os.date("%Y%m%d-%H%M%S"))
	local backupPath = string.format('backups/%s.sql', fileName)

	print(string.format('Saving database backup to: "^3%s^7"', backupPath))

	local payload = DB:CreateFullBackup()
	SaveResourceFile(GetCurrentResourceName(), backupPath, payload, -1)
end, true)
