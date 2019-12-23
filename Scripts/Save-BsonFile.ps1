<#
.Synopsis
	Saves the special file based collection to its source file.

.Description
	The command exports the collection created by Open-BsonFile to its file.

.Parameter Collection
		Specifies the collection instance. If it is defined by the variable
		$Collection then the parameter may be omitted.

.Parameter Path
		Specifies the source file to be saved. Its collection does not have to
		be opened, it is discovered by the file path. But the collection must
		exist.

.Parameter Force
		Tells to save even if the source file was removed or modified
		externally. By default, the command fails in such cases.

.Parameter Result
		Tells to output some file collection information.

.Parameter Changed
		Tells to save only if the collection is changed since the last sync.
		This option is effective with replica sets and shards.

.Outputs
	None or the information document.

.Link
	Open-BsonFile
#>

function Save-BsonFile {
	[CmdletBinding(DefaultParameterSetName='Collection')]
	param(
		[Parameter(ParameterSetName='Collection', Position=0)]
		[MongoDB.Driver.IMongoCollection[MongoDB.Bson.BsonDocument]]$Collection,
		[Parameter(ParameterSetName='Path', Position=0, Mandatory=1)]
		[string]$Path,
		[switch]$Force,
		[switch]$Result,
		[switch]$Changed
	)

	trap {Write-Error -ErrorRecord $_}

	Connect-Mdbc . BsonFile

	# resolve $Path, $md5, $info, $Collection
	if ($Path) {
		$Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
		$md5 = Get-BFPathMD5 $Path
		$info = Get-BFIndexInfo $md5
		if (!$info) {
			throw "File has no connected collection: '$Path'."
		}
		$Collection = Get-MdbcCollection $md5
	}
	else {
		. Resolve-BFCollection
	}

	# check file times and changes
	if (!$Force) {
		# file times
		$item = Get-Item -LiteralPath $Path
		if (!(Test-BFSameFileTime $info $item)) {
			throw "Different file times: expected $($info.FileTime.ToLocalTime()), actual $($item.LastWriteTime)."
		}

		# changes
		if ($Changed -and $info.SyncStamp) {
			$op = New-Object MongoDB.Driver.ChangeStreamOptions
			$op.StartAtOperationTime = $info.SyncStamp
			$op.BatchSize = 1
			$changes = $(
				$watch = Watch-MdbcChange -Collection $Collection -Options $op
				try {
					if ($watch.MoveNext()) {$watch.Current}
					if ($watch.MoveNext()) {$watch.Current}
				}
				finally {
					$watch.Dispose()
				}
			)
			if (!$changes) {
				if ($Result) {
					$info.IsExported = $false
					$info
				}
				return
			}
		}
	}

	# export
	Get-MdbcData | Export-MdbcData $Path

	# set index
	$item = Get-Item -LiteralPath $Path
	$info.FileTime = $item.LastWriteTimeUtc
	$info.SyncTime = $item.LastWriteTimeUtc
	$info.SyncStamp = Get-BFNextTimestamp
	Set-BFIndexInfo $info

	# result
	if ($Result) {
		if ($Changed) {
			$info.IsExported = $true
		}
		$info
	}
}
