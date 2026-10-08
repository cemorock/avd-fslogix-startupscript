$ErrorActionPreference = 'Stop'
$log = 'C:\ProgramData\avd-fslogix-config.log'
function Log($m) { "$(Get-Date -Format o) $m" | Out-File $log -Append -Encoding utf8 }

try {
    Log "Start, running as $(whoami)"

    $StorageAccount = 'saavdpspcs'
    $ShareName      = 'cfs-avd-p-spcs'
    $VhdPath        = "\\$StorageAccount.file.core.windows.net\$ShareName"

    function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Log "Set $Path\$Name = $Value"
    }

    # Entra Kerberos for Azure Files
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters' 'CloudKerberosTicketRetrievalEnabled' 1
    Set-Reg 'HKLM:\Software\Policies\Microsoft\AzureADAccount'      'LoadCredKeyFromProfile'              1

    # FSLogix profile container
    $fs = 'HKLM:\SOFTWARE\FSLogix\Profiles'
    Set-Reg $fs 'Enabled'                              1
    Set-Reg $fs 'VHDLocations'                         @($VhdPath) 'MultiString'
    Set-Reg $fs 'VolumeType'                           'VHDX'      'String'
    Set-Reg $fs 'ProfileType'                          0
    Set-Reg $fs 'DeleteLocalProfileWhenVHDShouldApply' 1
    Set-Reg $fs 'FlipFlopProfileDirectoryName'         1

    if (-not (Get-Service frxsvc -ErrorAction SilentlyContinue)) {
        Log 'WARNING: FSLogix service (frxsvc) not found - agent not installed'
    }
    Log 'Done'
    exit 0
}
catch {
    Log "FAILED: $($_.Exception.Message)"
    exit 1
}
