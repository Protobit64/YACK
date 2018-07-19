##############################
#.OUTPUT_Type CSV
#.OUTPUT_Name ProcessInfo.csv 
#
#.SYNOPSIS
# Gets general process information
#
#.DESCRIPTION
# Process Names
# 
#
#.EXAMPLE
# Get-ProcessInfo
#
#.NOTES
# ToDo - Include file information
##############################
function Get-ProcessInfo
{
    ### Voltaile
    #Get current running processes and sockets
    $ProcessList = $(Get-WmiObject -Class Win32_process) #Primary
    $ProcessList_ps = $(Get-Process) #Contains additional info
    #$NetstatOutput = $(netstat -a -o -n)

    #Find owners of those processes
    $ProcessOwners =  Get-ProcessOwners $ProcessList

    #Grabs processlist2's Modules and arrange it into ProcessList's order
    #$ProcessModules = Get-ProcessModules $ProcessList $ProcessList_ps

    ### Non-Voltaile

    #Hash Process's executable
    $ProcessExecutableHashes = Get-ProcessExeHashes $ProcessList

    #process's Executable Sig Check
    $ProcessExecutableSigCheck = Get-ProcessExeSig $ProcessList

    #Parse netstat output
    #$NetworkConnections = Convert-NetstatOutput $NetstatOutput
    #Find process's network connections
    #$ProcessNetworkConnections = Get-ProcessConnections $ProcessList $NetworkConnections

    #Determine Parent process names
    $ProcessParentNames = Get-ParentProcessNames $ProcessList

    #Process File Information
    #Company, FileVersion, ProductVersion, Description
    $FileInfo = Get-ProcessFileInfo $ProcessList $ProcessList_ps


    ### Output
    #Append information to results
    for ($i = 0; $i -lt $ProcessList.Length; $i++)
    {
        # Add Results
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "ProcessOwner" -Value $ProcessOwners[$i]
        $ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "MD5Hash" -Value $ProcessExecutableHashes[$i]
        #$ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "Connections" -Value $ProcessNetworkConnections[$i]
        #$ProcessList[$i] | Add-Member -MemberType NoteProperty -Name "Connections" -Value $ProcessConnectionList[$i]
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

    return $ProcessList
}

function Get-ProcessOwners ($ProcessList)
{
    $ProcessOwners = New-Object System.Collections.Generic.List[System.Object]

    foreach ($proc in $ProcessList)
    {
        #Find out username/domain of the owner
        try { 
            $owner = $($proc | Invoke-WmiMethod -Name GetOwner)  
            $ProcessOwners += $owner.User + "\" + $owner.Domain 
        }
        catch { 
            $ProcessOwners.Add("Error\Error")
        }
        
    }

    return $ProcessOwners
}

function Get-ProcessModules ($ProcessList, $ProcessList_ps)
{
    $ProcessModules = New-Object System.Collections.Generic.List[System.Object]

    foreach ($proc in $ProcessList)
    {
        $Modules = @()
        foreach ($proc_ps in $ProcessList_ps)
        {
            if ($proc.ProcessId -eq $proc_ps.ID)
            {
                $Modules = $proc_ps.Modules
            }
        }
        $ProcessModules.Add($Modules)
    }

    return $ProcessModules
}

function Get-ProcessFileInfo ($ProcessList, $ProcessList_ps)
{
    #$ProcessFileInfo = New-Object System.Collections.Generic.List[System.Object]
    $procFileInfo= @()

    foreach ($proc in $ProcessList)
    {
        $FileInfo = "" | Select-Object Company, FileVersion, ProductVersion, FileDescription
        
        foreach ($proc_ps in $ProcessList_ps)
        {
            if ($proc.ProcessId -eq $proc_ps.ID)
            {
                
                $FileInfo.Company, $FileInfo.FileVersion, $FileInfo.ProductVersion, $FileInfo.FileDescription = `
                $proc_ps.Company,   $proc_ps.FileVersion, $proc_ps.ProductVersion,  $proc_ps.FileDescription
                break
            }
        }
        $procFileInfo += $FileInfo
    }

    return $procFileInfo
}



function Get-ProcessExeHashes ($ProcessList) 
{
    $ProcessExecutableHashes = New-Object System.Collections.Generic.List[System.Object]

    $Sha1_Hasher = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    foreach ($proc in $ProcessList)
    {
        # Compute Hash of the file
        $hash = 0
        if ($proc.ExecutablePath -ne $null)
        {
            $hash = [System.BitConverter]::ToString($Sha1_Hasher.ComputeHash([System.IO.File]::ReadAllBytes($proc.ExecutablePath)))
            $hash = $hash.replace("-", "")
        }
        $ProcessExecutableHashes.Add($hash)
    }

    return $ProcessExecutableHashes
}

function Get-ProcessExeSig($ProcessList)
{
    $ProcessExecutableSigCheck = New-Object System.Collections.Generic.List[System.Object]

    foreach ($proc in $ProcessList)
    {
        if ($proc.ExecutablePath -ne $null)
        {
            # Compute Hash of the file
            $auth = Get-AuthenticodeSignature -FilePath $proc.ExecutablePath
            $ProcessExecutableSigCheck.Add($auth.Status)
        }
        else 
        {
            $ProcessExecutableSigCheck.Add("")
        }
    }

    return $ProcessExecutableSigCheck
}

function Convert-NetstatOutput ($NetstatOutput)
{
     ###### Convert netstat output -> variable
     $NetworkConnections = New-Object System.Collections.Generic.List[System.Object]
     #Get rid of the output headers
     $NetstatOutput = $NetstatOutput[4..$NetstatOutput.Length]
 
     #Loop through each line
     foreach ($connection in $NetstatOutput)
     {
         #Remove whitespace form start of line
         $connection = $connection -replace ('^\s+', '')
 
         #Split items on whitespace
         $connection = $connection -split ('\s+')
 
         #Parse items based on observed outcomes
         if ($connection.Length -eq 5) #All fields present
         {
             $properties = @{
                 Protocol = $connection[0]
                 LocalAddress = $connection[1]
                 ForeignAddress = $connection[2]
                 State = $connection[3]
                 PID = $connection[4]
             }
         }
         elseif ($connection.Length -eq 4) #State is missing
         {
             $properties = @{
                 Protocol = $connection[0]
                 LocalAddress = $connection[1]
                 ForeignAddress = $connection[2]
                 State = ""
                 PID = $connection[3]
             }
         }
         else { #Something went wrong
             $properties = @{
                 Protocol = ""
                 LocalAddress = ""
                 ForeignAddress = ""
                 State = ""
                 PID = ""
             }
         }
 
         #Add to resulting object
         $NetworkConnections.Add($(New-Object -TypeName PSObject -Property $properties))
     }

     return $NetworkConnections
}

function Get-ProcessConnectionList ($ProcessList, $NetworkConnections)
{
    ###### Create connection lists
    $ProcessConnectionList = New-Object System.Collections.Generic.List[System.Object]

    foreach ($proc in $ProcessList)
    {
        $Connections = ""
        foreach ($conn in $NetworkConnections)
        {
            if ($conn.PID -eq $proc.ProcessId)
            {
                $Connections += $conn.LocalAddress + "`n"
            }
        }
        $ProcessConnectionList.Add($Connections.Trim())
    }

    return $ProcessConnectionList
}


function Get-ProcessConnections ($ProcessList, $NetworkConnections)
{
    ###### Create connection lists
    $ProcessConnections = New-Object System.Collections.Generic.List[System.Object]

    #find the matching connection PID and process_list PIDs
    foreach ($proc in $ProcessList)
    {
        #Create a empty variable
        $Connections = @()

        foreach ($conn in $NetworkConnections)
        {
            if ($conn.PID -eq $proc.ProcessId)
            {
                $Connections += $conn
                
            }
        }
        $ProcessConnections.Add($Connections)
    }

    return $ProcessConnections
}


function Get-ParentProcessNames ($ProcessList)
{
    #Determine parent process names
    $ProcessParentNames = New-Object System.Collections.Generic.List[System.Object]

    foreach ($proc in $ProcessList)
    {
        $ParentName = ""
        foreach ($parentProc in $ProcessList)
        {
            if ($proc.ProcessId -eq $parentProc.ProcessId)
            {
                $ParentName = $parentProc.ProcessName
            }
        }
        $ProcessParentNames.Add($ParentName)
    }

    return $ProcessParentNames
}

return Get-ProcessInfo
#return "asd"
