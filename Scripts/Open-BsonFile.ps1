<#
.Synopsis
	Imports the bson/json file and connects its collection.

.Description
	The command imports data from the file to its collection and creates the
	variable $Collection in the calling scope. It also updates the index with
	file information for future operations.

	Use the connected collection $Collection for data queries and updates.
	After updates invoke Save-BsonFile in order to save data to the file.

.Parameter Path
		The .bson or .json file path. The file must exist but may be empty.

.Parameter Force
		Tells to import data even if the file has the same time as the last
		recorded. Potential changes in its collection will be overridden.

.Parameter CollectionVariable
		Specifies the custom variable name for the connected collection.
		The default is "Collection" to create the variable $Collection.

.Parameter Result
		Tells to output some file collection information.

.Outputs
	None or the information document.

.Link
	Save-BsonFile
#>

function Open-BsonFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=1, Position=0)]
		[string]$Path,
		[string]$CollectionVariable='Collection',
		[switch]$Force,
		[switch]$Result
	)

	trap {Write-Error -ErrorRecord $_}

	Connect-Mdbc . BsonFile

	$Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
	$item = Get-Item -LiteralPath $Path

	# path md5
	$md5 = Get-BFPathMD5 $Path

	# connect collection and set variable
	$Collection = Get-MdbcCollection $md5
	$PSCmdlet.SessionState.PSVariable.Set($CollectionVariable, $Collection)

	# check index info
	if (!$Force) {
		$info = Get-BFIndexInfo $md5
		if ($info) {
			if (Test-BFSameFileTime $info $item) {
				if ($Result) {
					$info.Documents = Get-MdbcData -Count
					$info.IsImported = $false
					$info
				}
				return
			}
		}
	}

	# import data
	Remove-MdbcCollection $md5
	Import-MdbcData $Path | Add-MdbcData

	# set index
	$info = New-MdbcData -Id $md5
	$info.Path = $Path
	$info.FileTime = $item.LastWriteTimeUtc
	$info.SyncTime = [DateTime]::UtcNow
	$info.SyncStamp = Get-BFNextTimestamp
	Set-BFIndexInfo $info

	# result
	if ($Result) {
		$info.Documents = Get-MdbcData -Count
		$info.IsImported = $true
		$info
	}
}
