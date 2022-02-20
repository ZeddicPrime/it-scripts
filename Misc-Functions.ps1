# A list of misc functions that can be plugged in to other scripts as needed

function Get-ADJoinType {
<#
.SYNOPSIS
    Checks local system for domain join type
.OUTPUTS
    One of the following string values:
        Hybrid
        AzureADNative
        AD
        Workgroup
        Unknown
#>
    try {
        $AzureADJoinedRaw = & dsregcmd /status | findstr AzureAdJoined
        $DomainJoinedRaw = & dsregcmd /status | findstr DomainJoined
        $AzureADJoined = ($AzureADJoinedRaw.Trim() -split ":")[1].Trim() -eq "YES"
        $DomainJoined = ($DomainJoinedRaw.Trim() -split ":")[1].Trim() -eq "YES"
    }
    catch { Write-Error "Unable to parse dsregcmd output" -ErrorAction Stop }
    if ($AzureADJoined -and $DomainJoined) { "Hybrid" }
    elseif ($AzureADJoined -and !$DomainJoined) { "AzureADNative" }
    elseif (!$AzureADJoined -and $DomainJoined) { "AD" }
    elseif (!$AzureADJoined -and !$DomainJoined) { "Workgroup" }
    else {
        Write-Error "Unable to determine join type" -ErrorAction Continue
        "Unknown"
    }
}
