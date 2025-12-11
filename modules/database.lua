DB = {
    cachedTables = {},
	cachePopulated = false,
}

---get all table names from the database
---@return string[]
function DB:GetTables()
	if self.cachePopulated then return self.cachedTables end

    local response = MySQL.query.await([[
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
        AND table_type = 'BASE TABLE';
    ]])

    local tableNames = {}
    for i = 1, #response do
        local table_name = response[i]?.table_name

        if table_name then
            tableNames[table_name] = true
        end
    end

	if type(Config.ExclusiveTables) == "table" then
		local filtered = {}
		for i = 1, #Config.ExclusiveTables do
			local tableName = Config.ExclusiveTables[i]

			if tableNames[tableName] then
				filtered[tableName] = true
			else
				warn(string.format('Table %s was listed in Config.ExclusiveTables but doesn\'t exist in the database !', tableName))
			end
		end

		self.cachedTables = filtered

		return filtered
	elseif type(Config.ExcludedTables) == "table" then
		for i = 1, #Config.ExcludedTables do
			local tableName = Config.ExcludedTables[i]

			if tableNames[tableName] then
				tableNames[tableName] = nil
			end
		end

		self.cachedTables = tableNames
	else
		self.cachedTables = tableNames
	end

	self.cachePopulated = true

    return self.cachedTables
end

---get the query to create the database table
---@param tableName string
---@return string createTableQuery
function DB:GetTableDef(tableName)
	if self.cachedTables[tableName] then goto valid end

    error(string.format('An invalid table name was passed to "DB:GetTableDef": %s', tableName))

    ::valid::

    local query = string.format("SHOW CREATE TABLE `%s`;", tableName)
    local data = MySQL.single.await(query)

    return data["Create Table"] .. ";"
end

---sanitize a value to be added to an insert query
---@param value any
---@return string
function DB:SanitizeValue(value)
    if type(value) == "number" then
        return tostring(value)
    elseif type(value) == "string" then
        local escapedString = string.gsub(value, "'", "''")

        return string.format("'%s'", escapedString)
    elseif type(value) == "boolean" then
        return value and "1" or "0"
    else
        return "NULL"
    end
end

---get the data from a table as an INSERT query
---@param tableName string
---@return string insertQuery
function DB:GetTableData(tableName)
	if self.cachedTables[tableName] then goto valid end

    error(string.format('An invalid table name was passed to "DB:GetTableDef": %s', tableName))

    ::valid::

	--[[ Considerations for improvement:
		- Splitting table up in smaller chunks to avoid oversized queries 
	]]

    local entryCountQuery = string.format("SELECT COUNT(1) as 'entries' FROM `%s`;", tableName)
	local tableEntries = MySQL.single.await(entryCountQuery)?.entries
	local packets = math.ceil(tableEntries / Config.QuerySize)

	local tableData = {}

	for i = 0, packets do
		local startIdx, size = i * Config.QuerySize, Config.QuerySize
		local query = string.format("SELECT * FROM `%s` LIMIT ?, ?;", tableName)
		local data = MySQL.query.await(query, {startIdx, size})

		tableData = CombineTables(tableData, data)
	end

    if #tableData < 1 then
        return string.format('-- No data for table: "%s"', tableName)
    end

    local columns = {}
    for column, _ in pairs(tableData[1]) do
        table.insert(columns, column)
    end

    local entries = {}
    for i = 1, #tableData do
        local entry, entryData = {}, tableData[i]

        for c = 1, #columns do
            local colName = columns[c]

            local sanitizedValue = DB:SanitizeValue(entryData[colName])

            table.insert(entry, sanitizedValue)
        end

        table.insert(entries, string.format(
            "(%s)", table.concat(entry, ', ')
        ))
    end

    local insertQuery = string.format(
        "-- Data for table: %s\nINSERT INTO `%s` (%s) VALUES\n\t%s\n;",
        tableName, tableName, table.concat(columns, ', '),
        table.concat(entries, ',\n\t')
    )

    return insertQuery
end

function DB:CreateFullBackup()
    local tables = DB:GetTables()

    local createQueries, insertQueries = {}, {}

    for i = 1, #tables do
        local tableName = tables[i]

        local createQuery = DB:GetTableDef(tableName)
        local insertQuery = DB:GetTableData(tableName)

        table.insert(createQueries, createQuery)
        table.insert(insertQueries, insertQuery)
    end

    return string.format(
        "%s\n\n%s\n\n%s\n\n%s", [[
        ------------------------------------------------------------------------
        --   ____                _          ___                  _            --
        --  / ___|_ __ ___  __ _| |_ ___   / _ \ _   _  ___ _ __(_) ___  ___  --
        -- | |   | '__/ _ \/ _` | __/ _ \ | | | | | | |/ _ \ '__| |/ _ \/ __| --
        -- | |___| | |  __/ (_| | ||  __/ | |_| | |_| |  __/ |  | |  __/\__ \ --
        --  \____|_|  \___|\__,_|\__\___|  \__\_\\__,_|\___|_|  |_|\___||___/ --
        ------------------------------------------------------------------------]],
        table.concat(createQueries, '\n\n'), [[
        -----------------------------------------------------------------------
        --  ___                     _      ___                  _            --
        -- |_ _|_ __  ___  ___ _ __| |_   / _ \ _   _  ___ _ __(_) ___  ___  --
        --  | || '_ \/ __|/ _ \ '__| __| | | | | | | |/ _ \ '__| |/ _ \/ __| --
        --  | || | | \__ \  __/ |  | |_  | |_| | |_| |  __/ |  | |  __/\__ \ --
        -- |___|_| |_|___/\___|_|   \__|  \__\_\\__,_|\___|_|  |_|\___||___/ --
        -----------------------------------------------------------------------]],
        table.concat(insertQueries, '\n\n')
    )
end
