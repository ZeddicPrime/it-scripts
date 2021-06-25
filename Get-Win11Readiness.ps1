<#
.SYNOPSIS
    Check if a computer is ready for Windows 11 based on TPM and SecureBoot status
.DESCRIPTION
    Built because the official Microsoft GUI solution doesn't work for enterprise managed devices
    Can be added as an SCCM script, an Intune script, etc for scale
    Can output to a CSV file on a local machine or to a fileshare
.EXAMPLE
    PS C:\> .\Get-Win11Readiness.ps1 -Simple
    
    Returns "Ready for Windows 11: True" (or False as appropriate)
.EXAMPLE
    PS C:\> .\Get-Win11Readiness.ps1 -Silent -File "\\Server\Share\Win11Readiness.csv"
    
    Outputs system detils to the specified CSV file. Can be run multiple times or against multiple computers
.EXAMPLE
    PS C:\> .\Get-Win11Readiness.ps1 | Out-GridView
    
    Creates a GUI window displaying details about the Windows 11 readiness state
.INPUTS
    None
.OUTPUTS
    Win11Readiness Custom Object. Can be piped into other commands as needed.
.NOTES
    Created by BenFTW
    
    To-Do:
    Fine-tune hardware details to better handle how different manufacturers report model/serial/etc
    Add detection if a CPU is new enough to be fully supported in Win11. This is a longshot...
    Make more end-user friendly. Integrate into PSADT for example to provide popups

    Version History:
    1.0.1: Fixed ability to gather Lenovo BIOS version
    1.0: Initial Release
#>

[CmdletBinding()]
param (
    # If set, outputs to a file
    [System.IO.FileInfo]$File,
    # If outputting to a file, overwrite existing data
    [switch]$Overwrite = $false,
    # If True, just out put True or False
    [switch]$Simple = $false,
    # If True, does not output to console. Use when writing to a file
    [switch]$Silent = $false
)

# Create custom PS Object
$Ready = [PSCustomObject]@{
    PSTypeName="Win11Readiness"
    Name = $env:COMPUTERNAME
    Date = Get-Date
    Ready = $null
    TPMVersion = $null
    UEFI = $null
    SecureBootEnabled = $null
    Manufacturer = $null
    Model = $null
    BIOSVersion = $null
    SerialNumber = $null
}

# Gather Data
    # TPM Version
        Try { $Ready.TPMVersion = [decimal](Get-WmiObject -Namespace "root\cimv2\security\microsofttpm" -Class win32_tpm -ErrorAction Stop).SpecVersion.Split(",")[0] }
        Catch { $Ready.TPMVersion = [decimal]0 }
    # Secure Boot and UEFI
        Try { $Ready.SecureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop }
        Catch { $Ready.SecureBootEnabled = $false }
    # UEFI
        # Check by looking if the system drive is formatted for GPT
        Try { $Ready.UEFI = [bool](Get-Disk | Where-Object { $_.IsSystem -and $_.PartitionStyle -eq "GPT" })}
        Catch { $Ready.UEFI = $false }
    # Hardware Details
        # Manufacturer
            Try {
            $Manufacturer = (Get-WmiObject -Class win32_ComputerSystem).Manufacturer
            # Override for non-standard Manufacturers
                if ($Manufacturer -like "*manufacturer*") { $Manufacturer = (Get-WmiObject -Class win32_baseboard).Manufacturer }
                if (!$Manufacturer) { $Manufacturer = (Get-WmiObject -Class win32_baseboard).Manufacturer }
            }
            Catch { $Manufacturer = $null }
                # Make naming more consistent
                if ($Manufacturer -like "*ASUS*") { $Manufacturer = "ASUS" }
                if ($Manufacturer -like "*Dell*") { $Manufacturer = "Dell" }
                if ($Manufacturer -like "*Hewlett*") { $Manufacturer = "HP" }
                if ($Manufacturer -eq "HPE") { $Manufacturer = "HP" }
                if ($Manufacturer -like "*Agilent*") { $Manufacturer = "Agilent" }
                if ($Manufacturer -like "*BOXX*") { $Manufacturer = "BOXX" }
                if ($Manufacturer -like "*EVGA*") { $Manufacturer = "EVGA" }
                if ($Manufacturer -like "*Gigabyte*") { $Manufacturer = "Gigabyte" }
                if ($Manufacturer -like "*Intel*") { $Manufacturer = "Intel" }
                if ($Manufacturer -like "*Lenovo*") { $Manufacturer = "LENOVO" }
                if ($Manufacturer -like "*Micro*Star*") { $Manufacturer = "Micro-Star" }
                if ($Manufacturer -like "*Zotac*") { $Manufacturer = "ZOTAC" }
                if ($Manufacturer -like "*Portwell*") { $Manufacturer = "Portwell" }
                $Ready.Manufacturer = $Manufacturer
        # Model / Serial Number / BIOS Version
            switch ($Manufacturer) {
                "LENOVO" {
                    $Model = (Get-WmiObject -Class win32_ComputerSystemProduct).Version
                    $SerialNumber = (Get-WmiObject -Class win32_Bios).SerialNumber
                    $BIOSVersion = (Get-WmiObject -Class win32_Bios).SMBIOSBIOSVersion
                }
                "ASUS" {
                    $Model = (Get-WmiObject -Class win32_BaseBoard).Product
                    if (!$Model) { $Model = (Get-WmiObject -Class win32_BaseBoard).Product }
                    $SerialNumber = (Get-WmiObject -Class win32_BaseBoard).SerialNumber
                    $BIOSVersion = (Get-WmiObject -Class win32_Bios).SMBIOSBIOSVersion
                }
                "Dell" {
                    $Model = (Get-WmiObject -Class win32_ComputerSystem).Model
                    if (!$Model) { $Model = (Get-WmiObject -Class win32_BaseBoard).Product }
                    $BIOSVersion = (Get-WmiObject -Class win32_Bios).SMBIOSBIOSVersion
                    $SerialNumber = (Get-WmiObject -Class win32_Bios).SerialNumber
                }
                default {
                    $Model = (Get-WmiObject -Class win32_ComputerSystem).Model
                    if (!$Model) { $Model = (Get-WmiObject -Class win32_BaseBoard).Product }
                    $BIOSVersion = (Get-WmiObject -Class win32_Bios).SMBIOSBIOSVersion
                    $SerialNumber = (Get-WmiObject -Class win32_BaseBoard).SerialNumber
                }
            }
            $Ready.Model = $Model
            $Ready.SerialNumber = $SerialNumber
            $Ready.BIOSVersion = $BIOSVersion

#Evaluate and output Data
    if ($Ready.TPMVersion -ge 2 -and $Ready.SecureBootEnabled) {
        $Ready.Ready = $true
    } else { $Ready.Ready = $false }

    if ($Simple -and !$Silent) {
        Write-Host "Ready for Windows 11: " -NoNewline
        $Ready.Ready
    }
    if (!$Simple -and !$Silent) { $Ready }

    if ($File) {
        Try {
            if (!(Test-Path -Path $File.Directory -PathType Container)) { New-Item $File.Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null }
            if ($Overwrite) { $Ready | Export-Csv -Path $File -Force -NoTypeInformation } else { $Ready | Export-Csv -Path $File -Force -NoTypeInformation -Append }
        }
        Catch { Write-Error "Unable to write output to a file" }
    }