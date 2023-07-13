<#
.DEPENDENCY 
.PSM_DEPENDENCY DataTransfer.psm1 

.SYNOPSIS
Gets general information on running processes

.NOTES
License: 
Credits: Connor Martin
#>



function Get-ProcessOwners ($ProcessList)
{
    <#
    .SYNOPSIS
    Returns a list of process owners that are in same order as ProcessList
    
    .PARAMETER ProcessList
    WMI Win32_process class list

    #>


    $ProcessOwners = New-Object System.Collections.Generic.List[System.Object]
    foreach ($Proc in $ProcessList)
    {
        if ($null -ne $Proc) # PS2.0 check
        {
            #Find out username/domain of the owner
            try 
            { 
                $owner = $($Proc | Invoke-WmiMethod -Name GetOwner)  
                $ProcessOwners += $owner.User + "\" + $owner.Domain 
            }
            catch 
            { 
                $ProcessOwners.Add("")
            }
        }
    }

    return $ProcessOwners
}

function Get-ProcessFileInfo ($ProcessList, $ProcessListPS)
{
    <#
    .SYNOPSIS
    Returns a list of process exe fileinfo that are in same order as ProcessList
    
    .PARAMETER ProcessList
    WMI Win32_process class list

    .PARAMETER ProcessList_ps
    PS Get-Process list
    #>

    $ProcFileInfo= @()

    foreach ($Proc in $ProcessList)
    {
        if ($null -ne $Proc) # PS2.0 check
        {
            $FileInfo = "" | Select-Object Company, FileVersion, ProductVersion, FileDescription
            
            foreach ($ProcPS in $ProcessListPS)
            {
                if ($null -ne $ProcPS) # PS2.0 check
                {
                    if ($Proc.ProcessId -eq $ProcPS.ID)
                    {
                        
                        $FileInfo.Company, $FileInfo.FileVersion, $FileInfo.ProductVersion, $FileInfo.FileDescription = `
                        $ProcPS.Company,   $ProcPS.FileVersion, $ProcPS.ProductVersion,  $ProcPS.FileDescription
                        break
                    }
                }
            }
            $ProcFileInfo += $FileInfo
        }
    }

    return $ProcFileInfo
}

function Get-ProcessExeHashes ($ProcessList)
{
    <#
    .SYNOPSIS
    Returns a list of process exe hashes that are in same order as ProcessList
    
    .PARAMETER ProcessList
    WMI Win32_process class list
    #>

    $ProcessExecutableHashes = New-Object System.Collections.Generic.List[System.Object]
    $MD5_Hasher = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    foreach ($Proc in $ProcessList)
    {
        if ($null -ne $Proc) # PS2.0 check
        {
            # Compute Hash of the file
            $Hash = 0
            if (($null -ne $Proc.ExecutablePath) -and (Test-Path $Proc.ExecutablePath -ErrorAction SilentlyContinue))
            {
                $Hash = [System.BitConverter]::ToString($MD5_Hasher.ComputeHash([System.IO.File]::ReadAllBytes($Proc.ExecutablePath)))
                $Hash = $Hash.replace("-", "")
            }
            $ProcessExecutableHashes.Add($Hash)
        }
    }

    return $ProcessExecutableHashes
}

function Get-ProcessExeSig($ProcessList)
{
    <#
    .SYNOPSIS
    Returns a list of sig checks that are in the same order as ProcessList
    
    .PARAMETER ProcessList
    WMI Win32_process class list
    #>

    #Iterate through each process exe path and authentice it's signature.
    $ProcessExecutableSigCheck = New-Object System.Collections.Generic.List[System.Object]
    foreach ($Proc in $ProcessList)
    {
        if ($null -ne $Proc) # PS2.0 check
        {
            if (($null -ne $Proc.ExecutablePath) -and (Test-Path $Proc.ExecutablePath -ErrorAction SilentlyContinue))
            {
                $Auth = Get-AuthenticodeSignature -FilePath $Proc.ExecutablePath
                $ProcessExecutableSigCheck.Add($Auth.Status)
            }
            else 
            {
                $ProcessExecutableSigCheck.Add("")
            }
        }
    }

    return $ProcessExecutableSigCheck
}

function Get-ParentProcessNames ($ProcessList)
{
    <#
    .SYNOPSIS
    Returns a list of process parents that in the same order as ProcessList
    
    .PARAMETER ProcessList
    WMI Win32_process class list
    #>

    #Find parent process name by looping through the table. Simple but slowish
    $ProcessParentNames = New-Object System.Collections.Generic.List[System.Object]
    foreach ($Proc in $ProcessList)
    {
        if ($null -ne $Proc) # PS2.0 check
        {
            $ParentName = ""
            foreach ($ParentProc in $ProcessList)
            {
                if ($null -ne $ParentProc) # PS2.0 check
                {
                    if ($Proc.ParentProcessId -eq $ParentProc.ProcessId)
                    {
                        $ParentName = $ParentProc.ProcessName
                    }
                }
            }
            $ProcessParentNames.Add($ParentName)
        }
    }

    return $ProcessParentNames
}


### Voltaile
#Get current running processes and sockets
$ProcessList = $(Get-WmiObject -Class Win32_process) #Primary
$ProcessListPS = $(Get-Process) #Contains additional info

#Find owners of those processes
$ProcessOwners =  Get-ProcessOwners $ProcessList #12.5s

### Non-Voltaile
#Hash Process's executable
$ProcessExecutableHashes = Get-ProcessExeHashes $ProcessList #5.7s

#process's Executable Sig Check
$ProcessExecutableSigCheck = Get-ProcessExeSig $ProcessList #27.5s

#Process File Information
$FileInfo = Get-ProcessFileInfo $ProcessList $ProcessListPS #3.3s

#Determine Parent process names
$ProcessParentNames = Get-ParentProcessNames $ProcessList #8.4 s


### Output
#Append information to results
for ($i = 0; $i -lt $ProcessList.Length; $i++)
{
    # Add Results
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ProcessOwner" -Value $ProcessOwners[$i]
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "MD5Hash" -Value $ProcessExecutableHashes[$i]
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ParentProcessName" -Value $ProcessParentNames[$i]
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ExeSigCheck" -Value $ProcessExecutableSigCheck[$i]

    #File Info
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "Company" -Value $FileInfo[$i].Company
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "FileVersion" -Value $FileInfo[$i].FileVersion
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ProductVersion" -Value $FileInfo[$i].ProductVersion
    $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "FileDescription" -Value $FileInfo[$i].FileDescription
}

#Select required values
$ProcessList = $($ProcessList | Select-Object -Property CSName, CreationDate, ProcessName, ProcessId, ParentProcessName, ParentProcessId, ProcessOwner, `
                                                        ExecutablePath, ExeSigCheck, Company, FileVersion, ProductVersion, FileDescription, `
                                                        CommandLine, SHA1Hash, HandleCount, ThreadCount, `
                                                        VirtualSize, ReadOperationCount, ReadTransferCount, WriteOperationCount, WriteTransferCount, `
                                                        UserModeTime, KernelModeTime)





YACKPipe-ReturnCSV -PowershellObjects $ProcessList -OutputName "Processes.csv" 

