<#
.Synopsis
	Removes orphan and old collections from the BsonFile database.

.Description
	This command removes file collections from the BsonFile database. By
	default this includes orphan collections with their files renamed or
	removed. Use CollectionAge and AllCollections in order to remove old
	or all collections. Use Verbose in order to get related messages.

.Parameter CollectionAge
		Tells to remove old collections and specifies the minimum age.

.Parameter AllCollections
		Tells to remove all collections. The command still discovers orphans
		and optional old collections and writes verbose messages about found.
#>

function Clear-BsonFile {
	[CmdletBinding()]
	param(
		[TimeSpan]$CollectionAge = [TimeSpan]::Zero,
		[switch]$AllCollections
	)

	trap {Write-Error -ErrorRecord $_}

	Connect-Mdbc . BsonFile _index

	foreach($info in Get-MdbcData) {
		# missing file
		if (!(Test-Path -LiteralPath $info.Path)) {
			Write-Verbose "Removing data of missing file $($info.Path)"
			Remove-MdbcCollection $info._id
			$info | Remove-MdbcData
		}
		# old collection
		elseif ($CollectionAge -gt [TimeSpan]::Zero) {
			$diff = [DateTime]::UtcNow - $info.SyncTime
			if ($diff -gt $CollectionAge) {
				Write-Verbose "Removing old $($diff) data of $($info.Path)"
				$info | Remove-MdbcData
				Remove-MdbcCollection $info._id
			}
		}
	}

	foreach($collection in Get-MdbcCollection) {
		try {
			$name = $collection.CollectionNamespace.CollectionName
			if ($name -ceq '_index') {
				continue
			}

			$md5 = [guid]$collection.CollectionNamespace.CollectionName
		}
		catch {
			Write-Warning "Unknown collection '$name', remove it manually."
			continue
		}

		if ($AllCollections) {
			Write-Verbose "Removing collection $md5"
			Remove-MdbcCollection $md5
		}
		elseif (!(Get-MdbcData @{_id = $md5})) {
			Write-Verbose "Removing collection $md5 without index record"
			Remove-MdbcCollection $md5
		}
	}
}
