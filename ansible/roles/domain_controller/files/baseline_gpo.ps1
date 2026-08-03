param(
    [string]$GpoName          = "Murphys Lab Baseline",
    [string]$MinPasswordLength = "14",
    [string]$DisableSmbV1      = "true",
    [string]$EnableRdp         = "true",
    [string]$EnableWinrm       = "true",
    [string]$DomainDn          = ""
)

$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

# Booleans arrive as strings (Ansible serialization varies); coerce explicitly
# so an unexpected value never silently reads as $true.
function ConvertTo-Bool([string]$v) { return ($v -match '^(?i:true|1|yes)$') }
$minLen  = [int]$MinPasswordLength
$doSmb   = ConvertTo-Bool $DisableSmbV1
$doRdp   = ConvertTo-Bool $EnableRdp
$doWinrm = ConvertTo-Bool $EnableWinrm

# ---- Domain default password policy (security settings, not a registry GPO) --
Set-ADDefaultDomainPasswordPolicy -Identity (Get-ADDomain).DistinguishedName `
    -MinPasswordLength $minLen -ComplexityEnabled $true
Write-Output "Password policy: min length $minLen, complexity enabled"

# ---- Baseline GPO (registry-based settings) ---------------------------------
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if ($null -eq $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment "Baseline security settings (Terraform/Ansible managed)"
    Write-Output "Created GPO '$GpoName'"
} else {
    Write-Output "GPO '$GpoName' already exists"
}

if ($doSmb) {
    Set-GPRegistryValue -Name $GpoName `
        -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
        -ValueName "SMB1" -Type DWord -Value 0 | Out-Null
    Write-Output "SMBv1 server disabled via GPO"
}

if ($doRdp) {
    Set-GPRegistryValue -Name $GpoName `
        -Key "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -ValueName "fDenyTSConnections" -Type DWord -Value 0 | Out-Null
    Write-Output "RDP enabled via GPO"
}

if ($doWinrm) {
    Set-GPRegistryValue -Name $GpoName `
        -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" `
        -ValueName "AllowAutoConfig" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GpoName `
        -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" `
        -ValueName "IPv4Filter" -Type String -Value "*" | Out-Null
    Write-Output "WinRM service auto-config enabled via GPO"
}

# ---- Link the GPO to the domain root ----------------------------------------
if ([string]::IsNullOrEmpty($DomainDn)) { $DomainDn = (Get-ADDomain).DistinguishedName }
try {
    New-GPLink -Name $GpoName -Target $DomainDn -LinkEnabled Yes -ErrorAction Stop | Out-Null
    Write-Output "Linked GPO '$GpoName' to $DomainDn"
} catch {
    if ($_.Exception.Message -match "already linked|already exists") {
        Write-Output "GPO '$GpoName' already linked to $DomainDn"
    } else {
        throw
    }
}
