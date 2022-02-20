<#
.SYNOPSIS
    Removes old desktop shortcuts to Software Center and creates a new one for Company Portal
.NOTES
    Designed to be deployed as an Intune Powershell Script
#>

#region Handle Desktop Shortcuts
# Build list of folders to search for links to Software Center
    $FoldersToSearch = @()
    $FoldersToSearch += Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
    $FoldersToSearch += Join-Path -Path $env:OneDriveCommercial -ChildPath "Desktop"
    $FoldersToSearch += Join-Path -Path $env:OneDrive -ChildPath "Desktop"
    $FoldersToSearch += Join-Path -Path $env:PUBLIC -ChildPath "Desktop"

# Search each folder recursively and build a list of ones to delete
    $Shortcuts = Get-ChildItem -Path $FoldersToSearch -Include *.lnk -Recurse
    $Shell = New-Object -ComObject WScript.Shell
    $MatchTarget = "C:\windows\CCM\scclient.exe,0" # Using the icon path because URI links seem wonky
    $RawLinks = ForEach ($Shortcut in $Shortcuts) { 
        [pscustomobject]@{
        Path = $Shortcut.FullName
        IconPath = $Shell.CreateShortcut($Shortcut).IconLocation
        }
    }
    $LinksToDelete = $RawLinks | Where-Object { $_.IconPath -eq $MatchTarget }
# Delete old shortcuts
    if ($LinksToDelete) { Remove-Item -Path $LinksToDelete.Path -Force }
#endregion Handle Desktop Shortcuts

# Handle Start Menu links
$StartPath = Join-Path -Path $env:ProgramData -ChildPath "\Microsoft\Windows\Start Menu\Programs\Microsoft Endpoint Manager\"
if (Test-Path -Path $StartPath -PathType Container) { Remove-Item -Path $StartPath -Recurse -Force }

# Create Company Portal Link
    # Make sure Company Portal is installed first, so that the icon shows correctly. If not, exit with an error to force a retry later
    if (!(Get-AppxPackage -Name Microsoft.CompanyPortal)) { exit 86 }

$new_object = New-Object -ComObject WScript.Shell
$destination = $new_object.SpecialFolders.Item("AllUsersDesktop")
$source_path = Join-Path -Path $destination -ChildPath "\\Company Portal.url"
$source = $new_object.CreateShortcut($source_path)
$source.TargetPath = "companyportal:"
$source.Save()
