
Import-Module BsonFile
$ScriptsRoot = "$(Split-Path (Get-Module BsonFile).Path)\Scripts"

# Synopsis: Basic open and save scenarios.
task Basic {
	# start with an empty file and no record
	Close-BsonFile z.json
	Set-Content z.json $null

	# open 1st - import
	$r = Open-BsonFile z.json -Result
	equals $r.Documents 0L
	equals $r.IsImported $true

	# open 2nd - skip
	$r = Open-BsonFile z.json -Result
	equals $r.IsImported $false

	# open Force - import
	$r = Open-BsonFile z.json -Force -Result
	equals $r.IsImported $true

	# change collection
	@{_id=1; op=1} | Add-MdbcData

	# save 1st - export, also test result =1=
	$r = Save-BsonFile
	equals $r $null
	$r = Import-MdbcData z.json
	equals "$r" '{ "_id" : 1, "op" : 1 }'

	# change file, save 2nd - error
	Start-Sleep -Milliseconds 50
	$null = New-Item z.json -ItemType File -Force
	try {Save-BsonFile; throw}
	catch {
		assert ("$_" -like "Different file times: expected *, actual *.")
		assert ($_.InvocationInfo.PositionMessage -like "At $BuildFile*")
	}

	# save -Force, also test result =1=
	$r = Save-BsonFile -Force -Result
	equals $r.Path "$PSScriptRoot\z.json"
	$r = Import-MdbcData z.json
	equals "$r" '{ "_id" : 1, "op" : 1 }'

	# kill file, save - error
	remove z.json
	try {Save-BsonFile; throw}
	catch {
		assert ("$_" -like "Cannot find path '*' because it does not exist.")
	}

	# save -Force
	Save-BsonFile -Force
	$r = Import-MdbcData z.json
	equals "$r" '{ "_id" : 1, "op" : 1 }'

	remove z.json
}

# Synopsis: Saving with -Changed checks.
task Changed {
	# a file with data and no record
	Close-BsonFile z.json
	@{_id = 1; x = 1} | Export-MdbcData z.json
	$time1 = (Get-Item z.json).LastWriteTimeUtc

	# open - import 1 document
	$r = Open-BsonFile z.json -Result
	equals $r.Documents 1L
	equals $r.IsImported $true

	# save changed - not changed
	$r = Save-BsonFile -Changed -Result
	$time2 = (Get-Item z.json).LastWriteTimeUtc
	equals $r.IsExported $false
	equals $time1 $time2

	# update data and save changed - changed
	Update-MdbcData @{} @{'$set' = @{x = 2}}
	$r = Save-BsonFile -Changed -Result
	$time3 = (Get-Item z.json).LastWriteTimeUtc
	equals $r.IsExported $true
	assert ($time3 -gt $time1)

	remove z.json
}

# Synopsis: Test BsonFile data and index and `Close-BsonFile -Path`.
task ClosePath Basic, {
	$module = Get-Module BsonFile

	$Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath('z.json')
	$md5 = & $module {Get-BFPathMD5 $args[0]} $Path

	Connect-Mdbc . BsonFile
	$_data = Get-MdbcCollection $md5
	$_index = Get-MdbcCollection _index

	equals 1L (Get-MdbcData -Count -Collection $_data)
	equals 1L (Get-MdbcData -Count @{_id = $md5} -Collection $_index)

	Close-BsonFile z.json

	equals 0L (Get-MdbcData -Count -Collection $_data)
	equals 0L (Get-MdbcData -Count @{_id = $md5} -Collection $_index)
}

# Synopsis: Test `Close-BsonFile -Collection`.
task CloseCollection {
	Set-Content z.bson $null
	Open-BsonFile z.bson

	# 1st - OK
	Close-BsonFile

	# 2nd - error
	try {
		Close-BsonFile -Collection $Collection
		throw
	}
	catch {
		equals "$_" "Collection has no record in 'BsonFile._index'."
	}

	remove z.bson
}

# Synopsis: Error on saving not registered file.
task SavePathMissingCollection {
	try {Save-BsonFile missing.bson; throw}
	catch {
		equals "$_" "File has no connected collection: '$PSScriptRoot\missing.bson'."
	}
}

# Synopsis: Error on saving not specified collection.
task SaveNotSpecifiedCollection {
	try {Save-BsonFile; throw}
	catch {
		equals "$_" "Specify a collection by the parameter or variable Collection."
	}
}

# Synopsis: Error on saving with invalid collection object.
task SaveBadCollection {
	try {Save-BsonFile $host; throw}
	catch {
		assert ("$_" -like "*parameter 'Collection'*Cannot convert*to type*MongoDB.Driver.IMongoCollection*")
	}
}

# Synopsis: Alien collections cause errors and not removed.
task AlienCollection {
	# connect an alien collection
	Connect-Mdbc . BsonFile alien -NewCollection
	@{_id = 64} | Add-MdbcData

	# save - error
	try {Save-BsonFile; throw}
	catch {
		equals "$_" "Collection BsonFile.alien is not supported."
	}

	# clear - warning
	$r = Clear-BsonFile 3>&1
	equals "$r" "Unknown collection 'alien', remove it manually."

	# not removed
	equals (Get-MdbcData)._id 64

	# remove
	Remove-MdbcCollection alien
	equals (Get-MdbcData) $null
}
