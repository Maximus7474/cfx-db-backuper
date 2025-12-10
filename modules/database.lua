DB = {
    cachedTables = {'users'}
}

---get all table names from the database
---@return string[]
function DB:GetTables()
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
            table.insert(tableNames, table_name)
        end
    end

    self.cachedTables = tableNames

    return tableNames
end

---get the query to create the database table
---@param tableName string
---@return string createTableQuery
function DB:GetTableDef(tableName)
    for i = 1, #self.cachedTables do
        local ref = self.cachedTables[i]

        if ref == tableName then goto valid end
    end

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
    for i = 1, #self.cachedTables do
        local ref = self.cachedTables[i]

        if ref == tableName then goto valid end
    end

    error(string.format('An invalid table name was passed to "DB:GetTableDef": %s', tableName))

    ::valid::

	--[[ Considerations for improvement:
		- Splitting table up in smaller chunks to avoid oversized queries 
	]]

    local query = string.format("SELECT * FROM `%s`;", tableName)
    local data = MySQL.query.await(query)

    if #data < 1 then
        return string.format('-- No data for table: "%s"', tableName)
    end

    local columns = {}
    for column, _ in pairs(data[1]) do
        table.insert(columns, column)
    end

    local entries = {}
    for i = 1, #data do
        local entry, entryData = {}, data[i]

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
        "-- Data for table: %s\nINSERT INTO `%s` (%s) VALUES (\n\t%s\n);",
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
