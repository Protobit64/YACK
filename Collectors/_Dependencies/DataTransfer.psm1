<#
.SYNOPSIS
A file for storing the functions used returning data from collectors.

.NOTES
Credit: Connor Martin
License: 
#>


function GetBase64GzippedStream ([System.IO.FileInfo]$File)
{
    <#
    .SYNOPSIS
    Gets a gzip encoded stream of the contents of a provided file path.
    
    .PARAMETER File
    The path to the file to be encoded.
    
    .NOTES
    GetBase64GzippedStream Version 0.1
    License: Apache License 2.0
    Credits: Connor Martin. kansa(github)
    #>


    # Open file for processing
    $FileStream = New-Object IO.FileStream $File, "OpenOrCreate", "Read", "ReadWrite"

    #Read file into byte array
    $MyBuffer = [System.Byte[]]::CreateInstance([System.Byte],$File.Length)
    #$MyBuffer = New-Object Byte[] $File.Length
    #$MyBuffer = [System.Byte[]]::new($File.Length)
    $temp = $FileStream.Read($MyBuffer, 0, $File.Length)

    # Create an empty memory stream to store our GZipped bytes in
    $MemStrm = New-Object System.IO.MemoryStream

    # Create a GZipStream with $MemStrm as its underlying storage
    $GZipStrm  = New-Object System.IO.Compression.GZipStream $MemStrm, ([System.IO.Compression.CompressionMode]::Compress)

    # Pass $memFile's bytes through the GZipstream into the $MemStrm
    $GZipStrm.Write($MyBuffer, 0, $File.Length)

    #Close and cleanup
    $FileStream.Dispose()
    $GZipStrm.Close()
    $GZipStrm.Dispose()
    $MyBuffer = $null
    
    # Return GZipped byte array
    return ,$MemStrm.ToArray()
}

function Get-FileChunksGZIP($SourceFilePath,  $YACKOutputFolder = $null, $OutputName = $null, $ChunkSize = 10MB)
{
    <#
    .SYNOPSIS
    Returns a file back to yack in file chunks. Each chunk is gzip-ed prior to transfer.

    .PARAMETER ChunkSize
    The size of the byte array that will be returned back to yack for each chunk

    .PARAMETER SourceFilePath
    The file to be transfered

    .PARAMETER YACKOutputFolder
    The folder the output should go into

    .NOTES
    Get-FileChunksGZIP Version 0.1
    #>

    #Expand the path
    $SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)

    #Seems reasonable
    $MaxChunkSize = $ChunkSize

    #Check if path exists and it's a file
    if (Test-Path $SourceFilePath -PathType Leaf)
    {
        #Attempt to open the file

        #Get file metadata
        $SourceTarget = Get-ChildItem $SourceFilePath -Force

        $File = [System.IO.FileInfo]$SourceTarget

        # Open file for processing
        $FileStream = New-Object IO.FileStream $File, "OpenOrCreate", "Read", "ReadWrite"

        $CurrentChunkInd = 0

        $TotalChunkInd = [int]($File.Length / $MaxChunkSize)
        for ($CurrentChunkInd = 0; ($CurrentChunkInd * $MaxChunkSize) -lt $File.Length; $CurrentChunkInd++)
        {
            #if (($MaxChunkSize * $CurrentChunkInd + $MaxChunkSize) -gt )
            #$CurrentChunkSize = $File.Length 

            if (($File.length - $FileStream.position) -gt $MaxChunkSize)
            {
                $NextChunkSize = $MaxChunkSize
            }
            else 
            {
                $NextChunkSize = ($File.length - $FileStream.position)
            }

            #Next Chunk Size
            
            #Read chunk
            $MyBuffer = [System.Byte[]]::CreateInstance([System.Byte],$NextChunkSize)
            $temp = $FileStream.Read($MyBuffer, 0, $MyBuffer.Length)

            # Create an empty memory stream to store our GZipped bytes in
            $MemStrm = New-Object System.IO.MemoryStream

            # Create a GZipStream with $MemStrm as its underlying storage
            $GZipStrm = New-Object System.IO.Compression.GZipStream $MemStrm, ([System.IO.Compression.CompressionMode]::Compress)

            # gzip some bytes
            $GZipStrm.Write($MyBuffer, 0, $MyBuffer.Length)

            #Close and cleanup
            $GZipStrm.Close()
            $GZipStrm.Dispose()
            
            #Create Collector results object
            $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

            if ($null -eq $OutputName)
            {
                $OutputName = $SourceTarget.Name 
            }

            $CollectorResult.Content = $MemStrm.ToArray()
            $CollectorResult.OutputType = "ChunkGZIP"
            $CollectorResult.OutputName = $OutputName #Default is module name
            $CollectorResult.OutputFolder = $YACKOutputFolder #Default is module folder

            #Add additional result attributes for CHUNK
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "CurrentChunk" -Value $CurrentChunkInd
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "MaxChunkSize" -Value $MaxChunkSize
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "TotalChunks" -Value $TotalChunkInd

            #Add additional result attributes for GZIP
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputCreationTimeUtc" -Value $SourceTarget.CreationTimeUtc
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputLastAccessTimeUtc" -Value $SourceTarget.LastAccessTimeUtc
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputLastWriteTimeUtc" -Value $SourceTarget.LastWriteTimeUtc


            $CollectorResult
        }

        $MyBuffer = $null
        $FileStream.Dispose()

    }
    else 
    {
        $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
        $CollectorResult.Error = $true
        $CollectorResult.ErrorMessage += "Invalid path $SourceFilePath"
        $CollectorResult
    }
}


function Get-FileChunks($SourceFilePath,  $YACKOutputFolder = $null, $OutputName = $null, $ChunkSize = 10MB)
{
    <#
    .SYNOPSIS
    Returns a file back to yack in file chunks

    .PARAMETER ChunkSize
    The size of the byte array that will be returned back to yack for each chunk

    .PARAMETER SourceFilePath
    The file to be transfered

    .PARAMETER YACKOutputFolder
    The folder the output should go into

    .NOTES
    Get-FileChunks Version 0.1
    #>

    #Expand the path
    $SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)

    #Seems reasonable
    $MaxChunkSize = $ChunkSize

    #Check if path exists and it's a file
    if (Test-Path $SourceFilePath -PathType Leaf)
    {
        #Attempt to open the file

        #Get file metadata
        $SourceTarget = Get-ChildItem $SourceFilePath -Force

        $File = [System.IO.FileInfo]$SourceTarget

        # Open file for processing
        $FileStream = New-Object IO.FileStream $File, "OpenOrCreate", "Read", "ReadWrite"

        $CurrentChunkInd = 0

        $TotalChunkInd = [int]($File.Length / $MaxChunkSize)
        for ($CurrentChunkInd = 0; ($CurrentChunkInd * $MaxChunkSize) -lt $File.Length; $CurrentChunkInd++)
        {

            if (($File.length - $FileStream.position) -gt $MaxChunkSize)
            {
                $NextChunkSize = $MaxChunkSize
            }
            else 
            {
                $NextChunkSize = ($File.length - $FileStream.position)
            }

            #Next Chunk Size
            
            #Read chunk
            $MyBuffer = [System.Byte[]]::CreateInstance([System.Byte],$NextChunkSize)
            $temp = $FileStream.Read($MyBuffer, 0, $MyBuffer.Length)

            
            #Create Collector results object
            $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

            if ($null -eq $OutputName)
            {
                $OutputName = $SourceTarget.Name 
            }

            $CollectorResult.Content = $MyBuffer
            $CollectorResult.OutputType = "ChunkBytes"
            $CollectorResult.OutputName = $OutputName #Default is module name
            $CollectorResult.OutputFolder = $YACKOutputFolder #Default is module folder

            #Add additional result attributes for CHUNK
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "CurrentChunk" -Value $CurrentChunkInd
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "MaxChunkSize" -Value $MaxChunkSize
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "TotalChunks" -Value $TotalChunkInd

            #Add additional result attributes for GZIP
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputCreationTimeUtc" -Value $SourceTarget.CreationTimeUtc
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputLastAccessTimeUtc" -Value $SourceTarget.LastAccessTimeUtc
            $CollectorResult | Add-Member -MemberType NoteProperty -Name "OutputLastWriteTimeUtc" -Value $SourceTarget.LastWriteTimeUtc


            $CollectorResult
        }

        $MyBuffer = $null
        $FileStream.Dispose()

    }
    else 
    {
        $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
        $CollectorResult.Error = $true
        $CollectorResult.ErrorMessage += "Invalid path $SourceFilePath"
        $CollectorResult
    }
}


function YACKPipe-ReturnFolderOrFile($SourceFilePath, $YACKOutputFolder, $OutputNameModifier = "", $GZIP = $false, $ChunkSize = 10MB)
{
    <#
    .SYNOPSIS
    Reads a folder and its contents from the filesystem. Each file is gzip encoded.
    Iterate over all child items. Pass back file if it's a file. Pass back directory if it's a directory

    .PARAMETER SourceFilePath
    Path of the folder to retrieve. Envr Variables are supported.

    .PARAMETER YACKOutputFolder
    The outputfolder which YACK will store the retrieved file.
    This parameters is passed back to YACK.ps1

    .PARAMETER OutputNameModifier
    It will append each output file name with this string (before the extension)

    .PARAMETER GZIP
    A boolean. COntrols if the the results are GZIP-ed before being returned

    .PARAMETER ChunkSize
    The size of the byte array that will be returned back to yack for each chunk


    .NOTES
    YACKPipe-ReturnFolder Version 0.1
    #>


    #Create Collector results object
    $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content



    $SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)
    $SourceFilePath = $SourceFilePath -replace '\\\\', '\'

    #Check if path exists
    if (Test-Path $SourceFilePath)
    {
        #Iterate through each item/child item
        $ChildItems = Get-ChildItem -Recurse -Path $SourceFilePath -Force
        foreach ($Child in $ChildItems)
        {
            if ($null -ne $Child) # PS2.0 check
            {
                $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
                try 
                {
                    #Grab folder or file
                    if ($Child.PSIsContainer)
                    {
                        $RelativePath = $($Child.Fullname).Replace($SourceFilePath, '')
                        $CollectorResult.Content = $null
                        $CollectorResult.OutputType = "Folder"
                        $CollectorResult.OutputName = $Child.Name + $OutputNameModifier
                        $CollectorResult.OutputFolder = $YACKOutputFolder + '\' + $RelativePath 

                        #Return result
                        $CollectorResult
                    }
                    else 
                    {
                        #If the target is a container
                        if (Test-Path $SourceFilePath -pathtype container)
                        {
                            $RelativePath = $($Child.Fullname.Replace($Child.Name, '')).Replace($SourceFilePath, '')
                        }
                        else 
                        {
                            $RelativePath = "\"
                        }

                        $ModifiedOutputFilename = "$($Child.BaseName)$OutputNameModifier$($Child.Extension)"

                        #If the file is supposed to be returned as a gzip or not
                        if ($GZIP)
                        {
                            Get-FileChunksGZIP -ChunkSize $ChunkSize -SourceFilePath $Child.FullName `
                                -YACKOutputFolder $($YACKOutputFolder + "\" + $RelativePath) -OutputName $ModifiedOutputFilename
                        }
                        else 
                        {
                            Get-FileChunks -ChunkSize $ChunkSize -SourceFilePath $Child.FullName `
                                -YACKOutputFolder $($YACKOutputFolder + "\" + $RelativePath) -OutputName $ModifiedOutputFilename
                        }
                    }
                }
                catch 
                {
                    #If an error was encountered during the process
                    $CollectorResult.Content = $null
                    $CollectorResult.Error = $true
                    $CollectorResult.ErrorMessage += "Failed Reading $SourceFilePath... $($_.Exception.Message) At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) char:$($_.InvocationInfo.OffsetInLine)"
                    return $CollectorResult
                }
            }
        }
    }
    else 
    {
        $CollectorResult.Error = $true
        $CollectorResult.ErrorMessage += "Invalid path $SourceFilePath"
        return $CollectorResult
    }
}


function YACKPipe-ReturnFile($SourceFilePath, $YACKOutputFolder = $null, $OutputName = $null, $GZIP = $false, $ChunkSize = 10MB)
{
    <#
    .SYNOPSIS
    Returns a file from the filesystem to the controlling script.
    The object is then output as a file with the same attributes at the original.
    
    .PARAMETER SourceFilePath
    The path to the file to be exported by to yack

    .PARAMETER YACKOutputFolder
    (OPTIONAL) The name of the folder that the output will be deposited in.

    .PARAMETER OutputName
    (OPTIONAL) The name of file that the objects will be output into.

    .PARAMETER GZIP
    (OPTIONAL) If the result return back to the controlling script is transmitted gziped.

    .PARAMETER ChunkSize
    (OPTIONAL) The size of how large each chunk is return back to yack. This prevents loading the
    the entire file being loaded into memory.
    
    .EXAMPLE
    YACKPipe-ReturnFile -SourceFilePath $OutputPath -YACKOutputFolder $YACKOutputFolder -OutputName $null -GZIP $False -ChunkSize 10MB 
    
    .NOTES
    YACKPipe-ReturnFile Version 0.1
    #>
    
    #Create Collector results object
    $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

    $SourceFilePath = [Environment]::ExpandEnvironmentVariables($SourceFilePath)

    #Check if path exists
    if (Test-Path $SourceFilePath)
    {
        #Iterate through each item/child item
        $ChildItems = Get-ChildItem -Recurse -Path $SourceFilePath -Force
        foreach ($Child in $ChildItems)
        {
            if ($null -ne $Child) # PS2.0 check
            {
                $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content
                try 
                {
                    #If the target is a container
                    if (Test-Path $SourceFilePath -pathtype container)
                    {
                        $RelativePath = $($Child.Fullname.Replace($Child.Name, '')).Replace($SourceFilePath, '')
                    }
                    else 
                    {
                        $RelativePath = $null
                    }
                    
                    
                    #If the file is supposed to be returned as a gzip or not
                    if ($GZIP)
                    {
                        Get-FileChunksGZIP -ChunkSize $ChunkSize -SourceFilePath $Child.FullName `
                            -YACKOutputFolder $($YACKOutputFolder + $RelativePath) -OutputName $OutputName
                    }
                    else 
                    {
                        Get-FileChunks -ChunkSize $ChunkSize -SourceFilePath $Child.FullName `
                            -YACKOutputFolder $($YACKOutputFolder + $RelativePath) -OutputName $OutputName
                    }
                }
                catch 
                {
                    #If an error was encountered during the process
                    $CollectorResult.Content = $null
                    $CollectorResult.Error = $true
                    $CollectorResult.ErrorMessage += "Failed Reading $SourceFilePath... $($_.Exception.Message) At $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber) char:$($_.InvocationInfo.OffsetInLine)"
                    return $CollectorResult
                }
            }
        }
    }
    else 
    {
        $CollectorResult.Error = $true
        $CollectorResult.ErrorMessage += "Invalid path $SourceFilePath"
        return $CollectorResult
    }
}

function YACKPipe-ReturnArray($ArrayResult, $YACKOutputFolder = $null, $OutputName = $null)
{
    <#
    .SYNOPSIS
    Returns a powershell  array back to the controlling script yack.ps1
    The object is then output as a raw file with a newline between each item.
    
    .PARAMETER ArrayResult
    The powershell array to be output to the file.

    .PARAMETER YACKOutputFolder
    (OPTIONAL) The name of the folder that the output will be deposited in.

    .PARAMETER OutputName
    (OPTIONAL) The name of file that the objects will be output into.
    
    .EXAMPLE
    YACKPipe-ReturnArray -ArrayResult $AllEvents.ToArray() -OutputName "HipShield.json"
    
    .NOTES
    YACKPipe-ReturnArray Version 0.1
    #>

    $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

    $CollectorResult.OutputType = "array"
    $CollectorResult.OutputName = $OutputName #Default is module name
    $CollectorResult.OutputFolder = $YACKOutputFolder
    $CollectorResult.Content = $ArrayResult

    $CollectorResult
}

function YACKPipe-ReturnError($ErrorMessage)
{
    <#
    .SYNOPSIS
    Returns an error message back to the controlling script
    
    .PARAMETER ErrorMessage
    A message that describes the error encountered
    
    .EXAMPLE
    YACKPipe-ReturnError "Couldn't find the folder"
    
    .NOTES
    YACKPipe-ReturnError Version 0.1
    #>

    $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

    $CollectorResult.Error = $true
    $CollectorResult.ErrorMessage = $ErrorMessage

    $CollectorResult
}


function YACKPipe-ReturnCSV($PowershellObjects, $YACKOutputFolder = $null, $OutputName = $null)
{
    <#
    .SYNOPSIS
    Returns a powershell object back to the controlling script yack.ps1
    The object is then output as a CSV.
    
    .PARAMETER PowershellObjects
    The powershell object array to be output to the csv

    .PARAMETER YACKOutputFolder
    (OPTIONAL) The name of the folder that the output will be deposited in.

    .PARAMETER OutputName
    (OPTIONAL) The name of file that the objects will be output into.
    
    .EXAMPLE
    YACKPipe-ReturnCSV -PowershellObjects $Listings -OutputName "DirListing_$Outputname.csv"
    
    .NOTES
    YACKPipe-ReturnCSV Version 0.1
    #>

    $CollectorResult = "" | Select-Object Error, ErrorMessage, OutputType, OutputName, OutputFolder, Content

    $CollectorResult.OutputType = "CSV"
    $CollectorResult.OutputName = $OutputName #Default is module name
    $CollectorResult.OutputFolder = $YACKOutputFolder
    $CollectorResult.Content = $PowershellObjects

    $CollectorResult
}



Export-ModuleMember -Function YACKPipe-ReturnFolderOrFile
Export-ModuleMember -Function YACKPipe-ReturnFile
Export-ModuleMember -Function YACKPipe-ReturnArray
Export-ModuleMember -Function YACKPipe-ReturnCSV
Export-ModuleMember -Function YACKPipe-ReturnError

