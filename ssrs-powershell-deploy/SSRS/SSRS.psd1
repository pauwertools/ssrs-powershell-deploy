@{
	RootModule = "SSRS"
	ModuleVersion = '1.3.1.0'
	GUID = '0bb2c38b-f8ac-4328-9cd6-359a4fd47991'
	Author = 'Paul W. and teams'
	Description = 'A public fork of https://github.com/timabell/ssrs-powershell-deploy - PowerShell module to deploy SQL Server Reporting Services project(s) (`.rptproj`) to a Reporting Server'
	HelpInfoURI = 'https://github.com/pauwertools/ssrs-powershell-deploy'
	FunctionsToExport = @("Publish-SSRSProject", "Publish-SSRSSolution", "New-SSRSWebServiceProxy")
}

