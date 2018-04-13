
$ProcessList = $(Get-WmiObject -Class Win32_process)
$ProcessParentNames = @()
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
    $ProcessParentNames += $ParentName
}
$ProcessList