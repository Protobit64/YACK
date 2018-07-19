##############################
#.OUTPUT_Type CSV
#.OUTPUT_Name ProcessHandles.csv
#.DEPENDENCY handle.exe handle64.exe
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
#General notes
##############################



<#
.SYNOPSIS
Converts the output of sysinternals Handles.exe into 

.DESCRIPTION
Long description

.PARAMETER HandleOutput
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Format-Handles ($HandleOutput)
{
    if ($HandleOutput -eq $null)
    {
        return $null
    }

    #Trim empty Lines
    $HandleOutput = $HandleOutput | Where-Object {$_.Trim() -ne ""}

    $parsedHandles = New-Object System.Collections.Generic.List[System.Object]

    $i = 0
    while($i -le $HandleOutput.Count)
    {
        #Find Start of section
        if ($HandleOutput[$i] -like '--------*')
        {
            $lineSplit = $HandleOutput[$i+1].Split(" ")

            #Parse Process Name
            $ProcName = $lineSplit[0]
            #PID
            $procPID = $lineSplit[2]
            #Owner
            $owner = $lineSplit[3]
            if ($owner -eq '\<unable') {
                $owner = 'unk'
            }

            #Iterate through handles for the file
            $j = $i + 2
            while (($HandleOutput[$j] -notlike '--------*') `
                -and ($j -le $HandleOutput.Count))
            {
                $trimmmed_line = $($HandleOutput[$j] -replace '\s+', ' ').TrimEnd()
                $lineSplit2 = $trimmmed_line.Split(" ")

                $handleType = $lineSplit2[2]
                #if there is a value...
                if ($lineSplit2.Length -gt 3)
                {
                    switch ($handleType)
                    {
                        "File"
                            {
                                $handleNum = $lineSplit2[1] -replace ":", ""
                                #Permissions included
                                if ($lineSplit2[3] -like '(*'){
                                    $handlePerm = $lineSplit2[3]
                                    #concat the rest of the array
                                    $handleValue = "$($lineSplit2[4..($lineSplit2.length-1)])"
                                }
                                else {
                                    $handlePerm = ""
                                    #concat the rest of the array
                                    $handleValue = "$($lineSplit2[3..($lineSplit2.length-1)])"
                                }

                                #Add to list
                                $pObj = New-Object -TypeName PSObject
                                $pObj | Add-Member -MemberType NoteProperty -Name "Process Name" -Value $ProcName
                                $pObj | Add-Member -MemberType NoteProperty -Name "PID" -Value $procPID
                                $pObj | Add-Member -MemberType NoteProperty -Name "Owner" -Value $owner
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Type" -Value $handleType
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Permissions" -Value $handlePerm
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Value" -Value $handleValue
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Number" -Value $handleNum

                                $parsedHandles.Add($pObj)
                                break
                            }
                        "Key"
                            {
                                $handleNum = $lineSplit2[1] -replace ":", ""
                                $handlePerm = ""
                                #concat the rest of the array
                                $handleValue = "$($lineSplit2[3..($lineSplit2.length-1)])"

                                $pObj = New-Object -TypeName PSObject
                                $pObj | Add-Member -MemberType NoteProperty -Name "Process Name" -Value $ProcName
                                $pObj | Add-Member -MemberType NoteProperty -Name "PID" -Value $procPID
                                $pObj | Add-Member -MemberType NoteProperty -Name "Owner" -Value $owner
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Type" -Value $handleType
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Permissions" -Value $handlePerm
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Value" -Value $handleValue
                                $pObj | Add-Member -MemberType NoteProperty -Name "Handle Number" -Value $handleNum

                                $parsedHandles.Add($pObj)
                                break
                            }

                        Default {}
                    }
                }


                $j++
            }

            #continue where j left off
            $i = $j
        }
        else {
            $i++
        }
    }


    return $parsedHandles
}


    


# Point path
$binFolder = "$env:TMP\yack"

#Select binary
if ([Environment]::Is64BitProcess) {
    $binary = "handle64.exe"
} else {
    $binary = "handle.exe"
}

#Build binary path
$binPath = "$binFolder\$binary"



#Run handles.exe if it exists
if ($(Test-Path "$binPath") -eq $true)
{
    $HandleOutput = $(& $binPath "/accepteula" "-a")
    return Format-Handles $handleOutput
}
else {
    return $null
}
