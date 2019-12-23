@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '0.0.0'
	Description = 'BSON/JSON file collections in MongoDB'
	CompanyName = 'https://github.com/nightroman'
	Copyright = 'Copyright (c) Roman Kuzmin'
	GUID = '2f56d5e7-be2f-4350-b645-5e4f7c664cbf'

	RootModule = 'BsonFile.psm1'
	RequiredModules = 'Mdbc'
	PowerShellVersion = '3.0'

	AliasesToExport = @()
	CmdletsToExport = @()
	VariablesToExport = @()
	FunctionsToExport = @(
		'Clear-BsonFile'
		'Close-BsonFile'
		'Open-BsonFile'
		'Save-BsonFile'
	)

	PrivateData = @{
		PSData = @{
			Tags = 'MongoDB', 'Mdbc', 'Database', 'BSON', 'JSON'
			ProjectUri = 'https://github.com/nightroman/BsonFile'
			LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
			ReleaseNotes = 'https://github.com/nightroman/BsonFile/blob/master/Release-Notes.md'
		}
	}
}
