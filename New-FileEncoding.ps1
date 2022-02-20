<#
.SYNOPSIS
    Encodes a file so it can be embedded in a powershell script
.DESCRIPTION
    Converts files to base64 byte encoding, and outputs either to a file
    or to the console. For best results, pipe the console output to clip.exe
    so that the output can easily be pasted into some other script.
    This script is designed for Intune so that a PowerShell script can be
    deployed that includes images or other content that would otherwise need
    to be packaged as a win32 app
.EXAMPLE
    PS C:\> New-FileEncoding.ps1 -Path ".\CompanyLogo.png" | clip
    Encodes the PNG file and places the output in your clipboard. In your
    target script, press Ctrl+V to paste it.
.EXAMPLE
    PS C:\> New-FileEncoding.ps1 -Path ".\CompanyLogo.png" -File
    Encodes the PNG file and places the output in a file called
    .\CompanyLogo-encoded.txt
.INPUTS
    Any valid file path
.OUTPUTS
    String representing the target file.
    When using the File switch, there is no console output.
.NOTES
    Note that some file types such as Windows shortcuts may not behave as
    expected.
    This isn't security! It obfuscates but does not protect sensitive data
    Sample code to use in other scripts to decode this file:
    $EncodedFile = "paste New-FileEncoding Output here"
    $CompanyLogo = [System.Convert]::FromBase64String($EncodedFile)
    Set-Content -Path C:\CompanyLogo.png -Value $CompanyLogo -Encoding Byte -Force
#>

param (
    [Parameter(Mandatory=$true,Position=1)]
    [System.IO.FileInfo]
    $Path,
    [switch]$File
)
if (!(Test-Path -Path $Path -PathType Leaf)) { Write-Error "File not found, or found a folder instead of a file" -ErrorAction Stop }

try { $Base64 = [System.Convert]::ToBase64String((Get-Content -Path $Path -Encoding Byte)) }
catch { Write-Error "Failed to convert file to Base64" -ErrorAction Stop }

if ($File) {
    $OutputPath = $Path.DirectoryName + "\" + $Path.BaseName + "-encoded.txt"
    try { $Base64 | Out-File -FilePath $OutputPath -ErrorAction Stop }
    catch { Write-Warning -Message "Failed to create $OutputPath" }
} else { $Base64 }
