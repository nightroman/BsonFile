$ErrorActionPreference = 1
Import-Module Mdbc

. $PSScriptRoot/Clear-BsonFile.ps1
. $PSScriptRoot/Close-BsonFile.ps1
. $PSScriptRoot/Open-BsonFile.ps1
. $PSScriptRoot/Save-BsonFile.ps1

function Get-BFPathMD5($Path) {
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Path.ToUpper())
	[guid][System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
}

function Get-BFIndexInfo($Id) {
	$Collection = Get-MdbcCollection _index
	Get-MdbcData @{_id = $Id}
}

function Set-BFIndexInfo($Info) {
	$Collection = Get-MdbcCollection _index
	$info | Set-MdbcData -Add
}

function Test-BFSameFileTime($Info, $Item) {
	$diff = ($Info.FileTime - $Item.LastWriteTimeUtc).TotalMilliseconds
	[Math]::Abs($diff) -lt 10
}

function Resolve-BFCollection {
	if (!$Collection) {
		$Collection = $PSCmdlet.SessionState.PSVariable.GetValue('Collection')
	}

	if ($Collection -isnot [MongoDB.Driver.IMongoCollection[MongoDB.Bson.BsonDocument]]) {
		throw 'Specify a collection by the parameter or variable Collection.'
	}

	try {
		$md5 = [guid]$Collection.CollectionNamespace.CollectionName
	}
	catch {
		throw "Collection $($Collection.CollectionNamespace.FullName) is not supported."
	}

	$info = Get-BFIndexInfo $md5
	if (!$info) {
		throw "Collection has no record in 'BsonFile._index'."
	}
	$Path = $info.Path
}

function Get-BFNextTimestamp {
	$r = Invoke-MdbcCommand @{ping = 1}
	$ts = $r['operationTime']
	if ($ts) {
		New-Object MongoDB.Bson.BsonTimestamp $ts.Timestamp, ($ts.Increment + 1)
	}
	else {
		$null
	}
}
