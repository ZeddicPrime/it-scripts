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
    Make more end-user friendly. Integrate into PSADT for example to provide popups

    Version History:
    1.0.4: Fixed parsing issue with CPU evaluation
    1.0.3: Added CPU, RAM and storage checks
    1.0.2: Added Secure Boot certificate checks
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
    SecureBootReady = $null
    RAMGB = $null
    RAMGB_Required = 4
    StorageGB = $null
    StorageGB_Required = 64
    CPUName = $null
    CPUSupported = $null
    Manufacturer = $null
    Model = $null
    BIOSVersion = $null
    SerialNumber = $null
}

# List of supported CPUs
$SupportedCPUs = @"
3015e
3020e
Athlon Gold 3150C
Athlon Gold 3150U
Athlon Silver 3050C
Athlon Silver 3050e
Athlon Silver 3050U
Athlon 3000G
Athlon 300GE
Athlon 300U
Athlon 320GE
Athlon Gold 3150G
Athlon Gold 3150GE
Athlon Silver 3050GE
EPYC 7232P
EPYC 7252
EPYC 7262
EPYC 7272
EPYC 7282
EPYC 7302
EPYC 7302P
EPYC 7352
EPYC 7402
EPYC 7402P
EPYC 7452
EPYC 7502
EPYC 7502P
EPYC 7532
EPYC 7542
EPYC 7552
EPYC 7642
EPYC 7662
EPYC 7702
EPYC 7702P
EPYC 7742
EPYC 7F32
EPYC 7F52
EPYC 7F72
EPYC 7H12
EPYC 72F3
EPYC 7313
EPYC 7313P
EPYC 7343
EPYC 73F3
EPYC 7413
EPYC 7443
EPYC 7443P
EPYC 7453
EPYC 74F3
EPYC 7513
EPYC 7543
EPYC 7543P
EPYC 75F3
EPYC 7643
EPYC 7663
EPYC 7713
EPYC 7713P
EPYC 7763
Ryzen 3 3250C
Ryzen 3 3250U
Ryzen 3 3200G
Ryzen 3 3200GE
Ryzen 3 3200U
Ryzen 3 3350U
Ryzen 3 2300X
Ryzen 3 5300U
Ryzen 3 3100
Ryzen 3 3300U
Ryzen 3 4300G
Ryzen 3 4300GE
Ryzen 3 4300U
Ryzen 3 5400U
Ryzen 3 PRO 3200G
Ryzen 3 PRO 3200GE
Ryzen 3 PRO 3300U
Ryzen 3 PRO 4350G
Ryzen 3 PRO 4350GE
Ryzen 3 PRO 4450U
Ryzen 3 PRO 5450U
Ryzen 5 3400G
Ryzen 5 3400GE
Ryzen 5 3450U
Ryzen 5 3500C
Ryzen 5 3500U
Ryzen 5 3550H
Ryzen 5 3580U
Ryzen 5 2500X
Ryzen 5 2600 
Ryzen 5 2600E
Ryzen 5 2600X
Ryzen 5 5500U
Ryzen 5 3500
Ryzen 5 3600
Ryzen 5 3600X
Ryzen 5 3600XT
Ryzen 5 4600G
Ryzen 5 4500U
Ryzen 5 4600GE
Ryzen 5 4600H
Ryzen 5 4600U
Ryzen 5 5600H
Ryzen 5 5600HS
Ryzen 5 5600U
Ryzen 5 5600X
Ryzen 5 PRO 3400G
Ryzen 5 PRO 3400GE
Ryzen 5 PRO 3500U
Ryzen 5 PRO 2600
Ryzen 5 PRO 3600
Ryzen 5 PRO 4650G
Ryzen 5 PRO 4650GE
Ryzen 5 PRO 4650U
Ryzen 5 PRO 5650U
Ryzen 7 3700C
Ryzen 7 3700U
Ryzen 7 3750H
Ryzen 7 3780U
Ryzen 7 2700 
Ryzen 7 2700E
Ryzen 7 2700X
Ryzen 7 5700U
Ryzen 7 3700X
Ryzen 7 3800X
Ryzen 7 3800XT
Ryzen 7 4700G
Ryzen 7 4700GE
Ryzen 7 4700U
Ryzen 7 4800H
Ryzen 7 4800HS
Ryzen 7 4800U
Ryzen 7 5800H
Ryzen 7 5800HS
Ryzen 7 5800U
Ryzen 7 5800
Ryzen 7 5800X
Ryzen 7 PRO 3700U
Ryzen 7 PRO 2700
Ryzen 7 PRO 2700X
Ryzen 7 PRO 4750G
Ryzen 7 PRO 4750GE
Ryzen 7 PRO 4750U
Ryzen 7 PRO 5850U
Ryzen 9 3900
Ryzen 9 3900X
Ryzen 9 3900XT
Ryzen 9 3950X
Ryzen 9 4900H
Ryzen 9 4900HS
Ryzen 9 5900HS
Ryzen 9 5900HX
Ryzen 9 5980HS
Ryzen 9 5980HX
Ryzen 9 5900
Ryzen 9 5900X
Ryzen 9 5950X
Ryzen 9 PRO 3900
Ryzen Threadripper 2920X
Ryzen Threadripper 2950X
Ryzen Threadripper 2970WX
Ryzen Threadripper 2990WX
Ryzen Threadripper 3960X
Ryzen Threadripper 3970X
Ryzen Threadripper 3990X
Ryzen Threadripper PRO 3945WX
Ryzen Threadripper PRO 3955WX
Ryzen Threadripper PRO 3975WX
Ryzen Threadripper PRO 3995WX
Atom(R) x6200FE
Atom(R) x6211E
Atom(R) x6212RE
Atom(R) x6413E
Atom(R) x6414RE
Atom(R) x6425E
Atom(R) x6425RE
Atom(R) x6427FE
Celeron(R) G4900
Celeron(R) G4900T
Celeron(R) G4920
Celeron(R) G4930
Celeron(R) G4930E
Celeron(R) G4930T
Celeron(R) G4932E
Celeron(R) G4950
Celeron(R) J4005
Celeron(R) J4105
Celeron(R) J4115
Celeron(R) N4000
Celeron(R) N4100
Celeron(R) 3867U
Celeron(R) 4205U
Celeron(R) 4305U
Celeron(R) 4305UE
Celeron(R) J4025
Celeron(R) J4125
Celeron(R) N4020
Celeron(R) N4120
Celeron(R) 5205U
Celeron(R) 5305U
Celeron(R) G5900
Celeron(R) G5900E
Celeron(R) G5900T
Celeron(R) G5900TE
Celeron(R) G5905
Celeron(R) G5905T
Celeron(R) G5920
Celeron(R) G5925
Celeron(R) J6412
Celeron(R) J6413
Celeron(R) N6210
Celeron(R) N6211
Celeron(R) N4500
Celeron(R) N4505
Celeron(R) N5100
Celeron(R) N5105
Celeron(R) 6305
Celeron(R) 6305E
Core(TM) i5-10210Y
Core(TM) i5-10310Y
Core(TM) i5-8200Y
Core(TM) i5-8210Y
Core(TM) i5-8310Y
Core(TM) i7-10510Y
Core(TM) i7-8500Y
Core(TM) m3-8100Y
Core(TM) i3-8100
Core(TM) i3-8100B
Core(TM) i3-8100H
Core(TM) i3-8100T
Core(TM) i3-8109U
Core(TM) i3-8140U
Core(TM) i3-8300
Core(TM) i3-8300T
Core(TM) i3-8350K
Core(TM) i5+8400
Core(TM) i5+8500
Core(TM) i5-8257U
Core(TM) i5-8259U
Core(TM) i5-8260U
Core(TM) i5-8269U
Core(TM) i5-8279U
Core(TM) i5-8300H
Core(TM) i5-8400
Core(TM) i5-8400B
Core(TM) i5-8400H
Core(TM) i5-8400T
Core(TM) i5-8500
Core(TM) i5-8500B
Core(TM) i5-8500T
Core(TM) i5-8600
Core(TM) i5-8600K
Core(TM) i5-8600T
Core(TM) i7-8086K
Core(TM) i7-8557U
Core(TM) i7-8559U
Core(TM) i7-8569U
Core(TM) i7-8700
Core(TM) i7-8700B
Core(TM) i7-8700K
Core(TM) i7-8700T
Core(TM) i7-8750H
Core(TM) i7-8850H
Core(TM) i3-8130U
Core(TM) i5-8250U
Core(TM) i5-8350U
Core(TM) i7-8550U
Core(TM) i7-8650U
Core(TM) i3-8145U
Core(TM) i3-8145UE
Core(TM) i5-8265U
Core(TM) i5-8365U
Core(TM) i5-8365UE
Core(TM) i7-8565U
Core(TM) i7-8665U
Core(TM) i7-8665UE
Core(TM) i3-9100
Core(TM) i3-9100E
Core(TM) i3-9100F
Core(TM) i3-9100HL
Core(TM) i3-9100T
Core(TM) i3-9100TE
Core(TM) i3-9300
Core(TM) i3-9300T
Core(TM) i3-9320
Core(TM) i3-9350K
Core(TM) i3-9350KF
Core(TM) i5-9300H
Core(TM) i5-9300HF
Core(TM) i5-9400
Core(TM) i5-9400F
Core(TM) i5-9400H
Core(TM) i5-9400T
Core(TM) i5-9500
Core(TM) i5-9500E
Core(TM) i5-9500F
Core(TM) i5-9500T
Core(TM) i5-9500TE
Core(TM) i5-9600
Core(TM) i5-9600K
Core(TM) i5-9600KF
Core(TM) i5-9600T
Core(TM) i7-9700
Core(TM) i7-9700E
Core(TM) i7-9700F
Core(TM) i7-9700K
Core(TM) i7-9700KF
Core(TM) i7-9700T
Core(TM) i7-9700TE
Core(TM) i7-9750H
Core(TM) i7-9750HF
Core(TM) i7-9850H
Core(TM) i7-9850HE
Core(TM) i7-9850HL
Core(TM) i9-8950HK
Core(TM) i9-9880H
Core(TM) i9-9900
Core(TM) i9-9900K
Core(TM) i9-9900KF
Core(TM) i9-9900KS
Core(TM) i9-9900T
Core(TM) i9-9980HK
Core(TM) i3-10100Y
Core(TM) i3-10110Y
Core(TM) i9-10900X
Core(TM) i9-10920X
Core(TM) i9-10940X
Core(TM) i9-10980XE
Core(TM) i3-10100
Core(TM) i3-10100E
Core(TM) i3-10100F
Core(TM) i3-10100T
Core(TM) i3-10100TE
Core(TM) i3-10105
Core(TM) i3-10105F
Core(TM) i3-10105T
Core(TM) i3-10110U
Core(TM) i3-10300
Core(TM) i3-10300T
Core(TM) i3-10305
Core(TM) i3-10305T
Core(TM) i3-10320
Core(TM) i3-10325
Core(TM) i5-10200H
Core(TM) i5-10210U
Core(TM) i5-10300H
Core(TM) i5-10310U
Core(TM) i5-10400
Core(TM) i5-10400F
Core(TM) i5-10400H
Core(TM) i5-10400T
Core(TM) i5-10500
Core(TM) i5-10500E
Core(TM) i5-10500H
Core(TM) i5-10500T
Core(TM) i5-10500TE
Core(TM) i5-10600
Core(TM) i5-10600K
Core(TM) i5-10600KF
Core(TM) i5-10600T
Core(TM) i7-10510U
Core(TM) i7-10610U
Core(TM) i7-10700
Core(TM) i7-10700E
Core(TM) i7-10700F
Core(TM) i7-10700K
Core(TM) i7-10700KF
Core(TM) i7-10700T
Core(TM) i7-10700TE
Core(TM) i7-10710U
Core(TM) i7-10750H
Core(TM) i7-10810U
Core(TM) i7-10850H
Core(TM) i7-10870H
Core(TM) i7-10875H
Core(TM) i9-10850K
Core(TM) i9-10885H
Core(TM) i9-10900
Core(TM) i9-10900E
Core(TM) i9-10900F
Core(TM) i9-10900K
Core(TM) i9-10900KF
Core(TM) i9-10900T
Core(TM) i9-10900TE
Core(TM) i9-10980HK
Core(TM) i3-1000G1
Core(TM) i3-1000G4
Core(TM) i3-1005G1
Core(TM) i5-1030G4
Core(TM) i5-1030G7
Core(TM) i5-1035G1
Core(TM) i5-1035G4
Core(TM) i5-1035G7
Core(TM) i5-1038NG7
Core(TM) i7-1060G7
Core(TM) i7-1065G7
Core(TM) i7-1068NG7
Core(TM) i3-L13G4
Core(TM) i5-L16G7
Core(TM) i5-11400
Core(TM) i5-11400F
Core(TM) i5-11400T
Core(TM) i5-11500
Core(TM) i5-11500T
Core(TM) i5-11600
Core(TM) i5-11600K
Core(TM) i5-11600KF
Core(TM) i5-11600T
Core(TM) i7-11700
Core(TM) i7-11700F
Core(TM) i7-11700K
Core(TM) i7-11700KF
Core(TM) i7-11700T
Core(TM) i9-11900
Core(TM) i9-11900F
Core(TM) i9-11900K
Core(TM) i9-11900KF
Core(TM) i9-11900T
Core(TM) i3-1110G4
Core(TM) i3-1115G4
Core(TM) i3-1115G4E
Core(TM) i3-1115GRE
Core(TM) i3-1120G4
Core(TM) i3-1125G4
Core(TM) i5-11300H
Core(TM) i5-1130G7
Core(TM) i5-1135G7
Core(TM) i5-1135G7
Core(TM) i5-1140G7
Core(TM) i5-1145G7
Core(TM) i5-1145G7E
Core(TM) i5-1145GRE
Core(TM) i7-11370H
Core(TM) i7-11375H
Core(TM) i7-1160G7
Core(TM) i7-1165G7
Core(TM) i7-1165G7
Core(TM) i7-1180G7
Core(TM) i7-1185G7
Core(TM) i7-1185G7E
Core(TM) i7-1185GRE
Pentium(R) CPU 4425Y
Pentium(R) CPU 6500Y
Pentium(R) CPU G5400
Pentium(R) CPU G5400T
Pentium(R) CPU G5420
Pentium(R) CPU G5420T
Pentium(R) CPU G5500
Pentium(R) CPU G5500T
Pentium(R) CPU G5600
Pentium(R) CPU G5600T
Pentium(R) CPU G5620
Pentium(R) Silver J5005
Pentium(R) Silver N5000
Pentium(R) CPU 4417U
Pentium(R) CPU 5405U
Pentium(R) Silver J5040
Pentium(R) Silver N5030
Pentium(R) CPU 6405U
Pentium(R) CPU G6400
Pentium(R) CPU G6400E
Pentium(R) CPU G6400T
Pentium(R) CPU G6400TE
Pentium(R) CPU G6405
Pentium(R) CPU G6405T
Pentium(R) CPU G6500
Pentium(R) CPU G6500T
Pentium(R) CPU G6505
Pentium(R) CPU G6505T
Pentium(R) CPU G6600
Pentium(R) CPU G6605
Pentium(R) 6805
Pentium(R) J6426
Pentium(R) N6415
Pentium(R) Silver N6000
Pentium(R) Silver N6005
Pentium(R) CPU 7505
Xeon(R) Bronze 3104
Xeon(R) Bronze 3106
Xeon(R) Gold 5115
Xeon(R) Gold 5118
Xeon(R) Gold 5119T
Xeon(R) Gold 5120
Xeon(R) Gold 5120T
Xeon(R) Gold 5122
Xeon(R) Gold 6126
Xeon(R) Gold 6126F
Xeon(R) Gold 6126T
Xeon(R) Gold 6128
Xeon(R) Gold 6130
Xeon(R) Gold 6130F
Xeon(R) Gold 6130T
Xeon(R) Gold 6132
Xeon(R) Gold 6134
Xeon(R) Gold 6136
Xeon(R) Gold 6138
Xeon(R) Gold 6138F
Xeon(R) Gold 6138P
Xeon(R) Gold 6138T
Xeon(R) Gold 6140
Xeon(R) Gold 6142
Xeon(R) Gold 6142F
Xeon(R) Gold 6144
Xeon(R) Gold 6146
Xeon(R) Gold 6148
Xeon(R) Gold 6148F
Xeon(R) Gold 6150
Xeon(R) Gold 6152
Xeon(R) Gold 6154
Xeon(R) Platinum 8153
Xeon(R) Platinum 8156
Xeon(R) Platinum 8158
Xeon(R) Platinum 8160
Xeon(R) Platinum 8160F
Xeon(R) Platinum 8160T
Xeon(R) Platinum 8164
Xeon(R) Platinum 8168
Xeon(R) Platinum 8170
Xeon(R) Platinum 8176
Xeon(R) Platinum 8176F
Xeon(R) Platinum 8180
Xeon(R) Silver 4108
Xeon(R) Silver 4109T
Xeon(R) Silver 4110
Xeon(R) Silver 4112
Xeon(R) Silver 4114
Xeon(R) Silver 4114T
Xeon(R) Silver 4116
Xeon(R) Silver 4116T
Xeon(R) E-2124
Xeon(R) E-2124G
Xeon(R) E-2126G
Xeon(R) E-2134
Xeon(R) E-2136
Xeon(R) E-2144G
Xeon(R) E-2146G
Xeon(R) E-2174G
Xeon(R) E-2176G
Xeon(R) E-2176M
Xeon(R) E-2186G
Xeon(R) E-2186M
Xeon(R) E-2224
Xeon(R) E-2224G
Xeon(R) E-2226G
Xeon(R) E-2226GE
Xeon(R) E-2234
Xeon(R) E-2236
Xeon(R) E-2244G
Xeon(R) E-2246G
Xeon(R) E-2254ME
Xeon(R) E-2254ML
Xeon(R) E-2274G
Xeon(R) E-2276G
Xeon(R) E-2276M
Xeon(R) E-2276ME
Xeon(R) E-2276ML
Xeon(R) E-2278G
Xeon(R) E-2278GE
Xeon(R) E-2278GEL
Xeon(R) E-2286G
Xeon(R) E-2286M
Xeon(R) E-2288G
Xeon(R) Bronze 3204
Xeon(R) Bronze 3206R
Xeon(R) Gold 5215
Xeon(R) Gold 5215L
Xeon(R) Gold 5217
Xeon(R) Gold 5218B
Xeon(R) Gold 5218N
Xeon(R) Gold 5218R
Xeon(R) Gold 5218T
Xeon(R) Gold 5220
Xeon(R) Gold 5220R
Xeon(R) Gold 5220S
Xeon(R) Gold 5220T
Xeon(R) Gold 5222
Xeon(R) Gold 6208U
Xeon(R) Gold 6209U
Xeon(R) Gold 6210U
Xeon(R) Gold 6212U
Xeon(R) Gold 6222V
Xeon(R) Gold 6226
Xeon(R) Gold 6226R
Xeon(R) Gold 6230
Xeon(R) Gold 6230N
Xeon(R) Gold 6230R
Xeon(R) Gold 6230T
Xeon(R) Gold 6238
Xeon(R) Gold 6238L
Xeon(R) Gold 6238T
Xeon(R) Gold 6240
Xeon(R) Gold 6240L
Xeon(R) Gold 6240R
Xeon(R) Gold 6240Y
Xeon(R) Gold 6242
Xeon(R) Gold 6242R
Xeon(R) Gold 6244
Xeon(R) Gold 6246R
Xeon(R) Gold 6248
Xeon(R) Gold 6248R
Xeon(R) Gold 6250
Xeon(R) Gold 6250L
Xeon(R) Gold 6252
Xeon(R) Gold 6252N
Xeon(R) Gold 6254
Xeon(R) Gold 6256
Xeon(R) Gold 6258R
Xeon(R) Gold 6262V
Xeon(R) Gold Gold 5218
Xeon(R) Gold Gold 6238R
Xeon(R) Gold6246
Xeon(R) Goldv 6234
Xeon(R) Platinum 8253
Xeon(R) Platinum 8256
Xeon(R) Platinum 8260
Xeon(R) Platinum 8260L
Xeon(R) Platinum 8260Y
Xeon(R) Platinum 8268
Xeon(R) Platinum 8270
Xeon(R) Platinum 8276
Xeon(R) Platinum 8276L
Xeon(R) Platinum 8280
Xeon(R) Platinum 8280L
Xeon(R) Platinum 9221
Xeon(R) Platinum 9222
Xeon(R) Platinum 9242
Xeon(R) Platinum 9282
Xeon(R) Silver 4208
Xeon(R) Silver 4209T
Xeon(R) Silver 4210
Xeon(R) Silver 4210R
Xeon(R) Silver 4210T
Xeon(R) Silver 4214
Xeon(R) Silver 4214R
Xeon(R) Silver 4214Y
Xeon(R) Silver 4215
Xeon(R) Silver 4215R
Xeon(R) Silver 4216
Xeon(R) W-2223
Xeon(R) W-2225
Xeon(R) W-2235
Xeon(R) W-2245
Xeon(R) W-2255
Xeon(R) W-2265
Xeon(R) W-2275
Xeon(R) W-2295
Xeon(R) W-3223
Xeon(R) W-3225
Xeon(R) W-3235
Xeon(R) W-3245
Xeon(R) W-3245M
Xeon(R) W-3265
Xeon(R) W-3265M
Xeon(R) W-3275
Xeon(R) W-3275M
Xeon(R) W-10855M
Xeon(R) W-10885M
Xeon(R) W-1250
Xeon(R) W-1250E
Xeon(R) W-1250P
Xeon(R) W-1250TE
Xeon(R) W-1270
Xeon(R) W-1270E
Xeon(R) W-1270P
Xeon(R) W-1270TE
Xeon(R) W-1290
Xeon(R) W-1290E
Xeon(R) W-1290P
Xeon(R) W-1290T
Xeon(R) W-1290TE
Xeon(R) Gold 5315Y
Xeon(R) Gold 5317
Xeon(R) Gold 5318N
Xeon(R) Gold 5318S
Xeon(R) Gold 5320
Xeon(R) Gold 5320T
Xeon(R) Gold 6312U
Xeon(R) Gold 6314U
Xeon(R) Gold 6326
Xeon(R) Gold 6330
Xeon(R) Gold 6330N
Xeon(R) Gold 6334
Xeon(R) Gold 6336Y
Xeon(R) Gold 6338
Xeon(R) Gold 6338N
Xeon(R) Gold 6338T
Xeon(R) Gold 6342
Xeon(R) Gold 6346
Xeon(R) Gold 6348
Xeon(R) Gold 6354
Xeon(R) Gold Gold 5318Y
Xeon(R) Platinum 8351N
Xeon(R) Platinum 8352S
Xeon(R) Platinum 8352V
Xeon(R) Platinum 8352Y
Xeon(R) Platinum 8358
Xeon(R) Platinum 8358P
Xeon(R) Platinum 8360Y
Xeon(R) Platinum 8368
Xeon(R) Platinum 8368Q
Xeon(R) Platinum 8380
Xeon(R) Silver 4309Y
Xeon(R) Silver 4310
Xeon(R) Silver 4310T
Xeon(R) Silver 4314
Xeon(R) Silver 4316
Snapdragon (TM) 850
Snapdragon (TM) 7c
Snapdragon (TM) 8c
Snapdragon (TM) 8cx
Microsoft SQ1
Microsoft SQ2
"@

# Gather Data
    # TPM Version
        Try { $Ready.TPMVersion = [decimal](Get-WmiObject -Namespace "root\cimv2\security\microsofttpm" -Class win32_tpm -ErrorAction Stop).SpecVersion.Split(",")[0] }
        Catch { $Ready.TPMVersion = [decimal]0 }
    # Secure Boot and UEFI
    Try {
        $Enabled = Confirm-SecureBootUEFI -ErrorAction Stop
        $ValidPolicy = (Get-SecureBootPolicy -ErrorAction Stop).Publisher -eq "77fa9abd-0359-4d32-bd60-28f4e78f784b"
        if ($Enabled -and $ValidPolicy) { $Ready.SecureBootReady = $true } else { $Ready.SecureBootReady = $false }
    }
    Catch { $Ready.SecureBootReady = $false }
    # UEFI
        # Check by looking if the system drive is formatted for GPT
        Try { $Ready.UEFI = [bool](Get-Disk | Where-Object { $_.IsSystem -and $_.PartitionStyle -eq "GPT" })}
        Catch { $Ready.UEFI = $false }
    # RAM
        Try { $Ready.RAMGB = [math]::ceiling((Get-WmiObject win32_physicalmemory | Measure-Object -Property Capacity -Sum).Sum/1gb) }
        Catch { $Ready.RAMGB = 0 }
    # Storage
        Try { $Ready.StorageGB = [math]::floor((Get-Volume -DriveLetter C).Size/1GB) }
        Catch { $Ready.StorageGB = 0 }
    # CPU
        $Ready.CPUName = (Get-WmiObject win32_processor).Name
        $ProcessedCPUs = foreach ($Processor in $SupportedCPUs.Split("`n").Trim()) {
            $Ready.CPUName.Contains($Processor)
        }
        $Ready.CPUSupported = $true -in $ProcessedCPUs
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
    if ($Ready.TPMVersion -ge 2 -and $Ready.SecureBootReady -and $Ready.RAMGB -ge $Ready.RAMGB_Required -and $Ready.StorageGB -ge $Ready.StorageGB_Required -and $Ready.CPUSupported) {
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
