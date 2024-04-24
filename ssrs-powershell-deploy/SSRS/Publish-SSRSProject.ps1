function Publish-SSRSProject{
	#requires -version 2.0
	[CmdletBinding()]
	# https://github.com/pauwertools/ssrs-powershell-deploy
	param (
		[parameter(Mandatory=$true)]
		[ValidatePattern('\.rptproj$')]
		[ValidateScript({ Test-Path -PathType Leaf -Path $_ })]
		[string]
		$Path,

		[parameter(Mandatory=$false)]
		[string]
		$Configuration,

		[parameter(Mandatory=$false)]
		[ValidatePattern('^https?://')]
		[string]
		$ServerUrl, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[string]
		$Folder, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[string]
		$DataSourceFolder, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[string]
		$DataSetFolder, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[string]
		$OutputPath, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[bool]
		$OverwriteDataSources, #THESE ARE NOW OVERRRIDES IF $Configuration is specified

		[parameter(Mandatory=$false)]
		[bool]
		$OverwriteDatasets, #THESE ARE NOW OVERRRIDES IF $Configuration is specified


		[System.Management.Automation.PSCredential]
		$Credential
	)

	$script:ErrorActionPreference = 'Stop'
	Set-StrictMode -Version Latest

	$Path = $Path | Convert-Path
	$ProjectRoot = $Path | Split-Path
	[xml]$Project = Get-Content -Path $Path

	$nsMgr = New-Object System.Xml.XmlNamespaceManager($Project.NameTable)
	$nsMgr.AddNamespace("ns", "http://schemas.microsoft.com/developer/msbuild/2003")

	# Select the nodes under Project/ItemGroup/Report using the registered namespace
	$reports = $Project.SelectNodes("//ns:Project/ns:ItemGroup/ns:Report", $nsMgr)
  	$datasets = $Project.SelectNodes("//ns:Project/ns:ItemGroup/ns:DataSet", $nsMgr)
  	$datasources = $Project.SelectNodes("//ns:Project/ns:ItemGroup/ns:DataSource", $nsMgr)

	#TBD: Configuration param not working
	if(![string]::IsNullOrEmpty($Configuration))
	{
		$Config = Get-SSRSProjectConfiguration -Path $Path -Configuration $Configuration

		if([string]::IsNullOrEmpty($ServerUrl))
		{
			Write-Verbose "Using Project Server URL: $($Config.ServerUrl)"
			$ServerUrl = $Config.ServerUrl
		}

		if([string]::IsNullOrEmpty($Folder))
		{
			Write-Verbose "Using Project Folder : $($Config.Folder)"
			$Folder = $Config.Folder
		}

		if([string]::IsNullOrEmpty($DataSourceFolder))
		{
			Write-Verbose "Using Project DataSourceFolder: $($Config.DataSourceFolder)"
			$DataSourceFolder = $Config.DataSourceFolder
		}

		if([string]::IsNullOrEmpty($DataSetFolder))
		{
			Write-Verbose "Using Project DataSetFolder: $($Config.DataSetFolder)"
			$DataSetFolder = $Config.DataSetFolder
		}

		if([string]::IsNullOrEmpty($OutputPath))
		{
			Write-Verbose "Using Project OutputPath: $($Config.OutputPath)"
			$OutputPath = $Config.OutputPath
		}

		if(!$PSBoundParameters.ContainsKey("OverwriteDataSources"))
		{
			Write-Verbose "Using Project OverwriteDataSources: $($Config.OverwriteDataSources)"
			$OverwriteDataSources = $Config.OverwriteDataSources
		}

		if(!$PSBoundParameters.ContainsKey("OverwriteDatasets"))
		{
			Write-Verbose "Using Project OverwriteDatasets: $($Config.OverwriteDatasets)"
			$OverwriteDatasets = $Config.OverwriteDatasets
		}
	}

	$reports | ForEach-Object {
        $CompiledRdlPath = $ProjectRoot | Join-Path -ChildPath $OutputPath | join-path -ChildPath $_.Include
        $RdlPath = $ProjectRoot | join-path -ChildPath $_.Include
        Write-Host $RdlPath
        if ((test-path $CompiledRdlPath) -eq $false)
        {
          write-error ('Report "{0}" is listed in the project but wasn''t found in the bin\ folder. Rebuild your project before publishing.' -f $CompiledRdlPath)
          break;
        }
        $RdlLastModified = (get-item $RdlPath).LastWriteTime
        $CompiledRdlLastModified = (get-item $CompiledRdlPath).LastWriteTime
        if ($RdlLastModified -gt $CompiledRdlLastModified)
        {
          write-error ('Report "{0}" in bin\ is older than source file "{1}". Rebuild your project before publishing.' -f $CompiledRdlPath,$RdlPath)
          break;
        }
      }


	$Folder = Normalize-SSRSFolder -Folder $Folder
	$DataSourceFolder = Normalize-SSRSFolder -Folder $DataSourceFolder

	$Proxy = New-SSRSWebServiceProxy -Uri $ServerUrl -Credential $Credential

	$FullServerPath = $Proxy.Url
	Write-Verbose "Connecting to: $FullServerPath"

	New-SSRSFolder -Proxy $Proxy -Name $Folder
	New-SSRSFolder -Proxy $Proxy -Name $DataSourceFolder
	New-SSRSFolder -Proxy $Proxy -Name $DataSetFolder

  $DataSourcePaths = @{}
  for($i = 0; $i -lt $datasources.Count; $i++) {
    $RdsPath = $ProjectRoot | Join-Path -ChildPath $datasources[$i].Include

    $DataSource = New-SSRSDataSource -Proxy $Proxy -RdsPath $RdsPath -Folder $DataSourceFolder -Overwrite $OverwriteDataSources
    $DataSourcePaths.Add($DataSource.Name, $DataSource.Path)
  }

	$DataSetPaths = @{}
	$datasets |
		ForEach-Object {
			$RsdPath = $ProjectRoot | Join-Path -ChildPath $_.Include
			$DataSet = New-SSRSDataSet -Proxy $Proxy -RsdPath $RsdPath -Folder $DataSetFolder -DataSourcePaths $DataSourcePaths -Overwrite $OverwriteDatasets
			if(-not $DataSetPaths.Contains($DataSet.Name))
			{
				$DataSetPaths.Add($DataSet.Name, $DataSet.Path)
			}
		}

	for($i = 0; $i -lt $reports.Count; $i++) {

            $extension = $reports[$i].Include.Substring($reports[$i].Include.length - 3 , 3)

			if(ImageExtensionValid -ext $extension){

				$PathImage = $ProjectRoot | Join-Path -ChildPath $reports[$i].Include
				$RawDefinition = Get-Content -Encoding Byte -Path $PathImage

				$DescProp = New-Object -TypeName SSRS.ReportingService2010.Property
				$DescProp.Name = 'Description'
				$DescProp.Value = ''
				$HiddenProp = New-Object -TypeName SSRS.ReportingService2010.Property
				$HiddenProp.Name = 'Hidden'
				$HiddenProp.Value = 'false'
				$MimeProp = New-Object -TypeName SSRS.ReportingService2010.Property
				$MimeProp.Name = 'MimeType'
				$MimeProp.Value = 'image/' + $extension

				$Properties = @($DescProp, $HiddenProp, $MimeProp)

				$Name = $reports[$i].Include
				Write-Verbose "Creating resource $Name"
				$warnings = $null
				$Results = $Proxy.CreateCatalogItem("Resource", $Project.Project.ItemGroup[1].Report[$i].Include, $Folder, $true, $RawDefinition, $Properties, [ref]$warnings)
			}
		}
  try {
    for($i = 0; $i -lt $reports.Count; $i++) {
      if($reports[$i].Include.EndsWith('.rdl')){
        $CompiledRdlPath = $ProjectRoot | Join-Path -ChildPath $OutputPath | join-path -ChildPath $reports[$i].Include
        New-SSRSReport -Proxy $Proxy -RdlPath $CompiledRdlPath -RdlName $reports[$i].Include
      }
  }
  }
  catch {
    Write-Host "Failed to publish report: $($_.Exception.Message)" -ForegroundColor Red
  }
	Write-host "Completed."
}

function ImageExtensionValid($ext){
    $valid = 0;

    Switch($ext)
    {
        'png' { $valid = 1; }
        'bmp' { $valid = 1; }
        'gif' { $valid = 1; }
        'jpg' { $valid = 1; }
    }

    return $valid;
}
