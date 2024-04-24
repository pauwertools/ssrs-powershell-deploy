# SSRS Powershell Deploy

* https://github.com/pauwertools/ssrs-powershell-deploy

PowerShell module to publish SQL Server Reporting Services project(s)
(`.rptproj`) to a Reporting Server



## This fork

This repository was forked from:
* https://github.com/timabell/ssrs-powershell-deploy

- added function New-SSRSWebServiceProxy to export
- modified Publish-SSRSProject to select the nodes using the registered namespace

## Installation

### From this Fork

To install this forked version, clone the repository and import the module:

```powershell
git clone https://github.com/pauwertools/ssrs-powershell-deploy.git
Import-Module ./ssrs-powershell-deploy/SSRS

See the exported commands with

	PS C:\Repos\SSRS> Get-Command -Module SSRS

	CommandType     Name                                               Version    Source
	-----------     ----                                               -------    ------
	Function        New-SSRSWebServiceProxy                            1.3.1.0    SSRS
	Function        Publish-SSRSProject                                1.3.1.0    SSRS
	Function        Publish-SSRSSolution                               1.3.1.0    SSRS


Unload again with

	PS C:\repo\ReportDefinitions> Remove-Module SSRS
