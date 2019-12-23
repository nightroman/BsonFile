<#
.Synopsis
	Removes the specified file collection and info.

.Description
	This command removes the specified file data from the BsonFile database.
	This includes the connected collection and the record in index.

.Parameter Collection
		Specifies the collection instance. If it is defined by the variable
		$Collection then the parameter may be omitted.

.Parameter Path
		Specifies the file path.
#>

function Close-BsonFile {
	[CmdletBinding()]
	param(
		[Parameter(ParameterSetName='Collection', Position=0)]
		[MongoDB.Driver.IMongoCollection[MongoDB.Bson.BsonDocument]]$Collection,
		[Parameter(ParameterSetName='Path', Position=0, Mandatory=1)]
		[string]$Path
	)

	trap {Write-Error -ErrorRecord $_}

	#! just database
	Connect-Mdbc . BsonFile

	# get $md5
	if ($Path) {
		$md5 = Get-BFPathMD5 ($PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path))
	}
	else {
		. Resolve-BFCollection
	}

	Remove-MdbcCollection $md5
	Remove-MdbcData @{_id = $md5} -Collection (Get-MdbcCollection _index)
}
