<#
.SYNOPSIS
    Remediation script for Viio browser extension registry configuration.
.DESCRIPTION
    Sets the "customerKey" and/or "employeeEmail" policy values for the Viio
    browser extension in Chrome and Edge (both Silent and Interactive editions).

    Supported use cases (controlled by the CONFIGURATION section below):
      * Set customer key only                 -> leave $EmployeeEmail empty
      * Set customer key and employee email   -> set $EmployeeEmail as well

    Scope rules:
      * customerKey  is REQUIRED and is ALWAYS written to HKLM (machine-wide).
      * employeeEmail is optional and can be written to HKLM or HKCU via $EmployeeEmailScope.

    Designed to run as SYSTEM ("Run this script using the logged-on credentials = No"
    in Intune). For HKCU scope, the value is written into the logged-on user's hive
    (HKEY_USERS\<SID>) rather than SYSTEM's own HKCU.
#>

# ============================ CONFIGURATION ============================

# Customer key. REQUIRED - always written to HKLM for every browser/edition.
$CustomerKey = "YOUR_CUSTOMER_KEY_HERE"

# Employee email. Leave empty ("") to skip setting employeeEmail.
# Use the literal value "AUTO" to derive it from the logged-on user's UPN.
$EmployeeEmail = "AUTO"

# Where to write employeeEmail: "HKLM" (machine-wide) or "HKCU" (per logged-on user).
$EmployeeEmailScope = "HKCU"

# ======================================================================

$ExtensionId = @{
    Silent      = "nffjckgmpigfpkmamacllkakieaphfnm"
    Interactive = "fjambfppaeandondpbbjkggkabeccjmh"
}

$BrowserPath = @{
    Chrome = "Google\Chrome"
    Edge   = "Microsoft\Edge"
}

function Get-PolicyPath {
    param([string]$Root, [string]$Browser, [string]$Edition)
    return "$Root\SOFTWARE\Policies\$($BrowserPath[$Browser])\3rdparty\extensions\$($ExtensionId[$Edition])\policy"
}

function Write-Diag {
    param([string]$Message)
    Write-Output "  [diag] $Message"
}

# Note: functions that produce a result do so through a [ref] out-param, not by
# returning it. Diagnostics are written to the Output stream (Write-Diag), so a
# plain `return $value` would hand the caller the diag lines AND the value as an
# array. The out-param keeps logging and the result cleanly separated.
function Resolve-LoggedOnUserSid {
    param([ref]$Sid)
    $loggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    Write-Diag "Win32_ComputerSystem.UserName: [$loggedOnUser]"
    if (-not $loggedOnUser) {
        throw "Could not determine the logged-on user."
    }
    $Sid.Value = (New-Object System.Security.Principal.NTAccount($loggedOnUser)).Translate(
                   [System.Security.Principal.SecurityIdentifier]).Value
}

function Get-DeviceJoinState {
    # dsregcmd /status is the authoritative source for Entra/AD join state.
    # Parse the handful of flags that decide whether AUTO can work at all.
    try {
        $status = & dsregcmd /status 2>$null
    }
    catch {
        Write-Diag "dsregcmd /status could not be run: $_"
        return
    }
    if (-not $status) {
        Write-Diag "dsregcmd /status returned no output."
        return
    }
    foreach ($flag in @("AzureAdJoined", "EnterpriseJoined", "DomainJoined", "WorkplaceJoined")) {
        $line = $status | Where-Object { $_ -match "^\s*$flag\s*:" } | Select-Object -First 1
        if ($line) { Write-Diag ("dsregcmd: " + ($line.Trim())) }
        else { Write-Diag "dsregcmd: $flag not found in output." }
    }
}

function Resolve-UpnFromActiveDirectory {
    param([string]$Sid, [ref]$Upn)
    # Bind to the user object in AD by SID and read userPrincipalName / mail.
    # Works while running as SYSTEM: the bind authenticates as the computer
    # account. Requires a reachable domain controller; on a workgroup or
    # off-network device (or a local-account SID) the bind throws and we skip.
    try {
        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($Sid)
        $bytes  = New-Object 'byte[]' $sidObj.BinaryLength
        $sidObj.GetBinaryForm($bytes, 0)
        $hex    = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''

        Write-Diag "Querying Active Directory for <SID=$hex>."
        $entry  = [ADSI]"LDAP://<SID=$hex>"
        $adUpn  = [string]$entry.Properties['userPrincipalName'].Value
        $adMail = [string]$entry.Properties['mail'].Value
        Write-Diag "AD userPrincipalName: [$adUpn]; mail: [$adMail]"

        # Prefer the UPN (matches the other sources); fall back to the mail attribute.
        $resolved = if ($adUpn) { $adUpn } elseif ($adMail) { $adMail } else { $null }
        if ($resolved) {
            $Upn.Value = $resolved
        }
        else {
            Write-Diag "AD object found but has no userPrincipalName/mail attribute."
        }
    }
    catch {
        Write-Diag "AD lookup failed (no DC reachable, not domain-joined, or local-account SID): $($_.Exception.Message)"
    }
}

function Resolve-Upn {
    param([string]$Sid, [ref]$Upn)
    # Resolve the logged-on user's UPN/email from, in priority order:
    #   1. Entra / WAM (AAD\Package)   - Entra joined or registered devices
    #   2. Office identity             - Office signed in with a work account
    #   3. Active Directory (by SID)   - on-prem AD-joined devices (needs a DC)
    # Sources 1-2 read the user's registry hive; source 3 does not. Resolve only
    # when exactly one distinct UPN is found; if ambiguous, leave $Upn unset so
    # the caller fails rather than guessing an email.

    Write-Diag "Resolving UPN for SID [$Sid]"
    Get-DeviceJoinState

    $upns = @()

    # Registry-based sources require the user's hive to be mounted. If the user
    # is not the active interactive session, HKEY_USERS\<SID> may be absent - we
    # skip these sources and still try Active Directory below.
    if (Test-Path "Registry::HKEY_USERS\$Sid") {
        Write-Diag "HKEY_USERS\$Sid hive is loaded."

        # --- Source 1: Entra / WAM (AAD\Package) ---
        # The AAD\Package\* glob can match multiple subkeys (multiple work/school accounts).
        $aadBase = "Registry::HKEY_USERS\$Sid\SOFTWARE\Microsoft\Windows\CurrentVersion\AAD\Package"
        if (Test-Path $aadBase) {
            $pkgKeys = @(Get-ChildItem $aadBase -ErrorAction SilentlyContinue)
            Write-Diag "AAD\Package exists with $($pkgKeys.Count) sub-package key(s)."
        }
        else {
            Write-Diag "AAD\Package path does NOT exist (device likely not Entra joined/registered)."
        }

        $upns = @((Get-ItemProperty "$aadBase\*" `
                  -ErrorAction SilentlyContinue).Username | Where-Object { $_ } | Select-Object -Unique)
        Write-Diag "AAD\Package Username matches: $($upns.Count) [$($upns -join '; ')]"

        # --- Source 2: Office identity fallback ---
        if ($upns.Count -eq 0) {
            $officePath = "Registry::HKEY_USERS\$Sid\SOFTWARE\Microsoft\Office\16.0\Common\Identity"
            if (Test-Path $officePath) {
                Write-Diag "Office Identity path exists; reading ADUserName."
            }
            else {
                Write-Diag "Office Identity path does NOT exist (Office not signed in with a work account)."
            }
            $upns = @((Get-ItemProperty $officePath `
                      -ErrorAction SilentlyContinue).ADUserName | Where-Object { $_ } | Select-Object -Unique)
            Write-Diag "Office ADUserName matches: $($upns.Count) [$($upns -join '; ')]"
        }
    }
    else {
        Write-Diag "HKEY_USERS\$Sid is NOT loaded; skipping registry sources."
    }

    # --- Source 3: on-prem Active Directory lookup by SID ---
    if ($upns.Count -eq 0) {
        $adUpn = $null
        Resolve-UpnFromActiveDirectory -Sid $Sid -Upn ([ref]$adUpn)
        if ($adUpn) { $upns = @($adUpn) }
    }

    if ($upns.Count -eq 0) {
        Write-Diag "No UPN found in any source."
        return
    }
    if ($upns.Count -gt 1) {
        Write-Diag "Multiple distinct UPNs found - ambiguous, refusing to guess."
        return
    }
    Write-Diag "Resolved UPN: [$($upns[0])]"
    $Upn.Value = $upns[0]
}

Write-Output "=== REMEDIATION START ==="
Write-Output "Running as: $(whoami)"

# ---- Validate configuration -------------------------------------------------

$setEmployeeEmail = -not [string]::IsNullOrWhiteSpace($EmployeeEmail)

if ([string]::IsNullOrWhiteSpace($CustomerKey) -or $CustomerKey -eq "YOUR_CUSTOMER_KEY_HERE") {
    Write-Output "CustomerKey is required but not configured. Set `$CustomerKey and re-run."
    exit 1
}

if ($setEmployeeEmail -and $EmployeeEmailScope -notin @("HKLM", "HKCU")) {
    Write-Output "Invalid EmployeeEmailScope: [$EmployeeEmailScope]. Must be 'HKLM' or 'HKCU'."
    exit 1
}

# ---- Resolve per-user context (only when needed) ----------------------------

$userSid = $null
$resolvedEmail = $EmployeeEmail

try {
    if ($setEmployeeEmail -and ($EmployeeEmailScope -eq "HKCU" -or $EmployeeEmail -eq "AUTO")) {
        Resolve-LoggedOnUserSid -Sid ([ref]$userSid)
        Write-Output "Logged-on user SID: [$userSid]"
    }

    if ($setEmployeeEmail -and $EmployeeEmail -eq "AUTO") {
        $resolvedEmail = $null
        Resolve-Upn -Sid $userSid -Upn ([ref]$resolvedEmail)
        if (-not $resolvedEmail) {
            Write-Output "Could not resolve employeeEmail from the logged-on user's UPN."
            exit 1
        }
        Write-Output "Resolved employeeEmail (UPN): [$resolvedEmail]"
    }
}
catch {
    Write-Output "Failed to resolve user context: $_"
    exit 1
}

# ---- Build the set of registry targets --------------------------------------
# Grouped by registry path so multiple values land in a single policy key.

$Targets = @{}   # path -> @{ Label; Props = @{ name = value } }

function Add-Target {
    param([string]$Label, [string]$Path, [string]$Name, [string]$Value)
    if (-not $Targets.ContainsKey($Path)) {
        $Targets[$Path] = @{ Label = $Label; Props = @{} }
    }
    $Targets[$Path].Props[$Name] = $Value
}

foreach ($browser in $BrowserPath.Keys) {
    foreach ($edition in $ExtensionId.Keys) {
        $label = "$browser - $edition"

        $hklmPath = Get-PolicyPath -Root "HKLM:" -Browser $browser -Edition $edition
        Add-Target -Label $label -Path $hklmPath -Name "customerKey" -Value $CustomerKey

        if ($setEmployeeEmail) {
            if ($EmployeeEmailScope -eq "HKLM") {
                $emailPath = Get-PolicyPath -Root "HKLM:" -Browser $browser -Edition $edition
            }
            else {
                $emailPath = Get-PolicyPath -Root "Registry::HKEY_USERS\$userSid" -Browser $browser -Edition $edition
            }
            Add-Target -Label $label -Path $emailPath -Name "employeeEmail" -Value $resolvedEmail
        }
    }
}

# ---- Apply -------------------------------------------------------------------

$ExitCode = 0

foreach ($path in $Targets.Keys) {
    $target = $Targets[$path]
    $pathCreated = $false

    try {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
            $pathCreated = $true
            Write-Output "$($target.Label) - Created path"
        }

        foreach ($name in $target.Props.Keys) {
            Set-ItemProperty -Path $path -Name $name -Value $target.Props[$name] -Type String -Force
            Write-Output "$($target.Label) - $name set successfully"
        }
    }
    catch {
        Write-Output "$($target.Label) - Failed: $_"
        # Only clean up paths we created in this run, to avoid clobbering existing config.
        if ($pathCreated -and (Test-Path $path)) {
            try {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                Write-Output "$($target.Label) - Cleaned up created path due to failure"
            }
            catch {
                Write-Verbose "Failed to clean up path $path : $_"
            }
        }
        $ExitCode = 1
    }
}

exit $ExitCode
