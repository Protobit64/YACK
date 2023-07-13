<#
.SYNOPSIS
Functions for interacting with logs.

.NOTES
Credit: Connor Martin. Matt McNabb
License: Apache 2.0 // MIT
#>


function Write-Log ($LogPath, $Text, [boolean]$ConsoleOutput=$true) 
{
    <#
    .SYNOPSIS
    Writes text to a log with a timestamp.
    
    .PARAMETER LogPath
    The path to the log to write to.
    
    .PARAMETER Text
    The text to be written
    
    .PARAMETER ConsoleOutput
    Boolean whether the text should be written to console.
    
    .NOTES
    Credit: Connor Martin
    License: 
    #>

    $Timestamp = $((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))

    #Write to Log
    "$Timestamp : $Text" | Out-File -Append "$LogPath"


    #If console output is enabled then print it to console
    if ($ConsoleOutput) 
    {
        #Write to console
        Write-Host "$Timestamp : $Text"
    }
}


function Read-CollectionLogInfo($CollectionLogPath)
{
<#
    .SYNOPSIS
    Reads the collect.log and parses out interesting information

    .PARAMETER CollectLogPath
    The path to the collect.log to parse information out of
    #>

    $LogInfo = @{
        "Successes"=0
        "Errors"=0
        "Total"=0
    }


    $CollectionLogContent = Get-Content $CollectionLogPath

    if ($CollectionLogContent.Length -lt 1)
    {
        $LogInfo["Successes"] = 0
        $LogInfo["Errors"] = 0

    }
    else 
    {
        $ErrorCount = 0
        foreach ($Line in $CollectionLogContent)
        {
            if ($Line -like "*!!! ERROR*")
            {
                $ErrorCount++
            }
        }

        $SucessCount = 0
        foreach ($Line in $CollectionLogContent)
        {
            if ($Line -like "*Collected:*")
            {
                $SucessCount++
            }
        }

        $LogInfo["Successes"] = $SucessCount
        $LogInfo["Errors"] = $ErrorCount
        $LogInfo["Total"] = $SucessCount + $ErrorCount
    }

    $LogInfo
}


#Matt McNabb
function Test-KeyPress
{
    <#
        .SYNOPSIS
        Checks to see if a key  are currently pressed.

        .DESCRIPTION
        Checks to see if a key or keys are currently pressed. If all specified keys are pressed then will return true, but if 
        any of the specified keys are not pressed, false will be returned.

        .PARAMETER Keys
        Specifies the key to check for. These must be of type "System.Windows.Forms.Keys"

        .EXAMPLE
        Test-KeyPress -Key ControlKey

        Check to see if the Ctrl key is pressed

        .LINK
        Uses the Windows API method GetAsyncKeyState to test for keypresses
        http://www.pinvoke.net/default.aspx/user32.GetAsyncKeyState

        The above method accepts values of type "system.windows.forms.keys"
        https://msdn.microsoft.com/en-us/library/system.windows.forms.keys(v=vs.110).aspx

        .LINK
        http://powershell.com/cs/blogs/tips/archive/2015/12/08/detecting-key-presses-across-applications.aspx

        .INPUTS
        System.Windows.Forms.Keys

        .OUTPUTS
        System.Boolean

        .NOTE
        License: MIT
    #>
    
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $KeyString
    )
    
    #Import Key assembly 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    $Key = [System.Windows.Forms.Keys]$KeyString

    # use the User32 API to define a keypress datatype
    $Signature = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
    public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@
    $API = Add-Type -MemberDefinition $Signature -Name 'Keypress' -Namespace Keytest -PassThru
    
    # test if each key in the collection is pressed
    [bool]($API::GetAsyncKeyState($Key) -eq -32767)

}
