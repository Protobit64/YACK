<#
.SYNOPSIS
Functions for moving dependencies for the YACKCollectors.

.NOTES
Credit: Connor Martin
License: 
#>


function Initialize-PSMDependencies ($Collectors, $DependenciesPath) 
{
    <#
    .SYNOPSIS
    Imports the powershell module dendencies in this ps session so the function are available.

    .PARAMETER Collectors
    The array that contains all the Collectors.

    .PARAMETER DependenciesPath
    The path which the dependency binaries are.

    .NOTES
    Credit: Connor Martin
    License: 
	#>
	
	#Create PSMDependencies List
	$PSMDependencies = @()

	#Build PSMDependencies list
	foreach ($Collecto in $Collectors) 
	{
		foreach ($Dep in $Collecto.PSMDependencies) 
		{
			if ($null -ne $Dep) #Ps 2.0 check
			{
				if ($($PSMDependencies -contains $Dep) -ne $true) 
				{
					$PSMDependencies += $Dep
				}
			}
		}
	}



	#If there is anything to run
	if ($PSMDependencies.Length -gt 0)
	{
		#Remove the modules before loading
		foreach ($Dep in $PSMDependencies) 
		{
			$moduleName = $(Get-Item "$DependenciesPath$Dep").BaseName
			$mod = Get-Module $moduleName
			if ($null -ne $mod)
			{
				Remove-Module $mod
			}
		}

		#Load Modules
		foreach ($Dep in $PSMDependencies) 
		{
			$null = Import-Module "$DependenciesPath$Dep" -WarningAction SilentlyContinue
			#$null = . "$DependenciesPath$Dep"
		}
	}
}


function Initialize-PSMDependenciesRemote ($Collectors, $DependenciesPath, $PSSession) 
{
    <#
    .SYNOPSIS
    Imports the powershell module dendencies into a remote session so the function are available.

    .PARAMETER Collectors
    The array that contains all the Collectors.

    .PARAMETER DependenciesPath
    The path which the dependency binaries are.

	.PARAMETER PSSession
    The PSSession to transfer files over.

    .NOTES
    Credit: Connor Martin
    License: 
	#>

	#Create PSMDependencies List
	$PSMDependencies = @()

	#Build PSMDependencies list
	foreach ($Collecto in $Collectors) 
	{
		foreach ($Dep in $Collecto.PSMDependencies) 
		{
			if ($null -ne $Dep) #Ps 2.0 check
			{
				if ($($PSMDependencies -contains $Dep) -ne $true) 
				{
					$PSMDependencies += $Dep
				}
			}
		}
	}


	#If there is anything to run
	if ($PSMDependencies.Length -gt 0)
	{
		#Include each dependency into the ps session
		foreach ($Dep in $PSMDependencies) 
		{
			Import-ModuleRemotely "$DependenciesPath$Dep" $PSSession
			#$null = . "$DependenciesPath$Dep"
		}
	}
}


function Import-ModuleRemotely([string] $modulePath,[System.Management.Automation.Runspaces.PSSession] $session)
{

	#https://stackoverflow.com/questions/14441800/how-to-import-custom-powershell-module-into-the-remote-session
	#Modifications made to support file paths

	#Parse out the module name form the path
	$moduleName = $(Get-Item $modulePath).BaseName
	
	#Retain if the module was already loaded or not
	$CurrentState = Get-Module $moduleName

	#Load the module if needed
	if ($null -eq $CurrentState)
	{
		Import-Module $modulePath -WarningAction SilentlyContinue
	}

	#Select module object
	$localModule = get-module $moduleName
	
	#Extract properties
    function Exports([string] $paramName, $dictionary) 
    { 
        if ($dictionary.Keys.Count -gt 0)
        {
            $keys = $dictionary.Keys -join ",";
            return " -$paramName $keys"
        }
    }
    $fns = Exports "Function" $localModule.ExportedFunctions;
    $aliases = Exports "Alias" $localModule.ExportedAliases;
    $cmdlets = Exports "Cmdlet" $localModule.ExportedCmdlets;
    $vars = Exports "Variable" $localModule.ExportedVariables;
    $exports = "Export-ModuleMember $fns $aliases $cmdlets $vars;";

	

    $moduleString= @"
if (get-module $moduleName )
{
    remove-module $moduleName;
}
New-Module -name $moduleName {
$($localModule.Definition)
$exports;
}  | import-module -WarningAction SilentlyContinue
"@
	$script = [ScriptBlock]::Create($moduleString);
	
	invoke-command -session $session -scriptblock $script;
	
	#Return state to what is was previously
	if ($null -eq $CurrentState)
	{
		remove-module $moduleName
	}
}



function Copy-Dependencies ($Collectors, $DependenciesPath) 
{
    <#
    .SYNOPSIS
    Copies dependicies to the target system.

    .DESCRIPTION
    Builds a list of all the dependices from the Collectors array. It then transfers these from the 
    dependieces folder to target system.

    .PARAMETER Collectors
    The array that contains all the Collectors.

    .PARAMETER DependenciesPath
    The path which the dependency binaries are.

    .NOTES
    Credit: Connor Martin
    License: 
    #>

    #Create Dependencies List
    $Dependencies = @()

    #Build dependencies list
    foreach ($Collecto in $Collectors) 
    {
        foreach ($Dep in $Collecto.Dependencies) 
        {
			if ($null -ne $Dep) #Ps 2.0 check
            {
				if ($($Dependencies -contains $Dep) -ne $true) 
				{
					$Dependencies += $Dep
				}
			}
        }
    }

    #If there is anything to transfer
    if ($Dependencies.Length -gt 0)
    {
        #Create Transfer Folder
        $TranferFolder = "$env:SystemRoot\yack"
        $null = New-Item -Path "$TranferFolder" -ItemType directory -Force

        #Transfer Dependencies
        foreach ($Dep in $Dependencies) 
        {
            $DepPath = "$DependenciesPath$Dep"
            if ($(Test-Path $DepPath) -eq $true) 
            {
                Copy-Item -Path $DepPath -Destination $TranferFolder -Recurse -Force
            }
        }
    }
}

function Copy-DependenciesRemote ($Collectors, $DependenciesPath, $PSSession) 
{
    <#
    .SYNOPSIS
    Copies dependicies to the target system.

    .DESCRIPTION
    Builds a list of all the dependices from the Collectors array. It then transfers these from the 
    dependieces folder to target system.

    .PARAMETER Collectors
    The array that contains all the Collectors.

    .PARAMETER DependenciesPath
    The path which the dependency binaries are.

    .PARAMETER PSSession
    The PSSession to transfer files over.

    .NOTES
    Credit: Connor Martin
    License: 
    #>

    #Create Dependencies List
    $Dependencies = @()

    #Build dependencies list
    foreach ($Collecto in $Collectors) 
    {
        foreach ($Dep in $Collecto.Dependencies) 
        {
			if ($null -ne $Dep) #ps 2.0 check
			{
				if ($Dependencies.Contains($Dep) -ne $true) 
				{
					$Dependencies += $Dep
				}
			}
        }
    }

    #If there is anything to transfer
    if ($Dependencies.Length -gt 0)
    {
        #Create Transfer Folder
        #$TranferFolder = "$env:TEMP\yack"
        
        foreach ($Dep in $Dependencies) 
        {
            $DepPath = "$DependenciesPath$Dep"
            if ($(Test-Path $DepPath) -eq $true) 
            {
                #Copy-Item -Path $DepPath -Destination $TranferFolder
                Send-File $DepPath "%SystemRoot%\YACK\" $PSSession
            }
        }

    
    }
}


function Send-File ([string[]]$SourcePaths, [string]$Destination, [System.Management.Automation.Runspaces.PSSession]$Session)
{
    <#
	.SYNOPSIS
		This function sends a file (or folder of files recursively) to a destination WinRm session. This function was originally
		built by Lee Holmes (http://poshcode.org/2216) but has been modified to support enviromental variables and PS 2.0.
		Has problems with files larger then 32MB.
    .PARAMETER SourcePaths
		The local or UNC folder path that you'd like to copy to the session. This also support multiple paths in a comma-delimited format.
		If this is a UNC path, it will be copied locally to accomodate copying.  If it's a folder, it will recursively copy
		all files and folders to the destination.
	.PARAMETER Destination
		The local path on the remote computer where you'd like to copy the folder or file.  If the folder does not exist on the remote
		computer it will be created.
	.PARAMETER Session
		The remote session. Create with New-PSSession.
	.EXAMPLE
		$session = New-PSSession -ComputerName MYSERVER
		Send-File -Path C:\test.txt -Destination C:\ -Session $session
		This example will copy the file C:\test.txt to be C:\test.txt on the computer MYSERVER
	.INPUTS
		None. This function does not accept pipeline input.
	.OUTPUTS
		System.IO.FileInfo
    #>
    
	# [CmdletBinding()]
	# param
	# (
	# 	[Parameter(Mandatory)]
	# 	[ValidateNotNullOrEmpty()]
	# 	[string[]]$SourcePaths,
		
	# 	[Parameter(Mandatory)]
	# 	[ValidateNotNullOrEmpty()]
	# 	[string]$Destination,
		
	# 	[Parameter(Mandatory)]
	# 	[System.Management.Automation.Runspaces.PSSession]$Session
	# )
	process
	{
		foreach ($p in $SourcePaths)
		{
			if ($null -ne $p) #ps2.0 check
			{
				try
				{
					if ($p.StartsWith('\\'))
					{
						Write-Verbose -Message "[$($p)] is a UNC path. Copying locally first"
						Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine'))
						$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
					}
					if (Test-Path -Path $p -PathType Container)
					{
						
						$files = Get-ChildItem -Force -Path $p -File -Recurse
						$sendFileParamColl = @()
						foreach ($file in $Files)
						{
							if ($null -ne $file) #ps 2.0 check
							{
								$sendParams = @{
									'SourcePaths' = $file.FullName
									'Destination' = $file.FullName
									'Session' = $Session
								}
								if ($file.DirectoryName -ne $p) ## It's a subdirectory
								{
									$sourcePath = $p -replace "\\\\", "\"
									$ParentFolder = $sourcePath | Split-path -leaf
									$subdirpath = $file.DirectoryName.Replace("$sourcePath\", '')
									$sendParams.Destination = "$Destination\$ParentFolder\$subDirPath"
								}
								else
								{
									$sendParams.Destination = $Destination
								}
								$sendFileParamColl += $sendParams
							}
						}
						foreach ($paramBlock in $sendFileParamColl)
						{
							if ($null -ne $paramBlock) #ps 2.0 check
							{
								Send-File @paramBlock
							}
						}
					}
					else
					{
						Write-Verbose -Message "Starting WinRM copy of [$($p)] to [$($Destination)]"
						# Get the source file, and then get its contents
						$sourceBytes = [System.IO.File]::ReadAllBytes($p);
						$streamChunks = @();
						
						# Now break it into chunks to stream.
						$streamSize = 1MB;
						for ($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize)
						{
							$remaining = $sourceBytes.Length - $position
							$remaining = [Math]::Min($remaining, $streamSize)
							
							$nextChunk = [System.Byte[]]::CreateInstance([System.Byte],$remaining)
							[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
							$streamChunks +=, $nextChunk
						}
						
						$remoteScript = 
						{
							param ( $Destination, 
							$TransferLength,
							$pPath )

							$Destination = [Environment]::ExpandEnvironmentVariables($Destination)

							if (-not (Test-Path -Path $Destination -PathType Container))
							{
								$null = New-Item -Path $Destination -Type Directory -Force
							}
							$fileDest = "$Destination\$($pPath | Split-Path -Leaf)"
							## Create a new array to hold the file content
							$destBytes = [System.Byte[]]::CreateInstance([System.Byte],$TransferLength)
							$position = 0
							
							## Go through the input, and fill in the new array of file content
							foreach ($chunk in $input)
							{
								if ($chunk -ne $null) #ps2.0 check
								{
									[GC]::Collect()
									[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
									$position += $chunk.Length
								}
							}
							
							[IO.File]::WriteAllBytes($fileDest, $destBytes)
							
							#Get-Item -Force $fileDest
							[GC]::Collect()
						}

						
						# Stream the chunks into the remote script.
						$Length = $sourceBytes.Length

						$streamChunks | Invoke-Command -Session $Session -ScriptBlock $remoteScript -ArgumentList $Destination, $Length, $p
						
						Write-Verbose -Message "WinRM copy of [$($p)] to [$($Destination)] complete"
					}
				}
				catch
				{
					Write-Error "$_.Exception.Message At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) char:$($_.InvocationInfo.OffsetInLine)"
				}
			}
		}
	}
	
}


function Remove-Dependencies 
{
    <#
    .SYNOPSIS
    Remove dependencies from the target system.

    .DESCRIPTION
    Removes the yack folder from the temp directory.

    .NOTES
    Credit: Connor Martin
    License: 
    #>

    $TranferFolder = "$env:SystemRoot\yack"
    if (Test-Path $TranferFolder) 
    {
		#Remove the folder and it's subitems. 2.0 code
		$FileTree = @(Get-Item $TranferFolder -Include "*" -Force) + 
        	(Get-ChildItem $TranferFolder -Recurse -Include "*" -Force) | 
        	sort pspath -Descending -unique

		$FileTree  | Remove-Item -force -recurse
    }
}
function Get-Tree($Path,$Include='*') { 
    
} 

function Remove-DependenciesRemote ($PSSession)
{
    <#
    .SYNOPSIS
    Remove dependencies from the target system via a pssession.

    .PARAMETER PSSession
    The PSSession to the system to have dependencies removed from.

    .NOTES
    Credit: Connor Martin
    License: 
    #>

	$SB =
	{
		$TranferFolder = "$env:SystemRoot\yack"
		if (Test-Path $TranferFolder) 
		{
			#Remove the folder and it's subitems. 2.0 code
			$FileTree = @(Get-Item $TranferFolder -Include "*" -Force) + 
				(Get-ChildItem $TranferFolder -Recurse -Include "*" -Force) | 
				sort pspath -Descending -unique

			$FileTree  | Remove-Item -force -recurse
		}
	}

	Invoke-Command -Session $Session -ScriptBlock $SB
}