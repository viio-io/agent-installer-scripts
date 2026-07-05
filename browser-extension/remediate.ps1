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

function Resolve-LoggedOnUserSid {
    $loggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    if (-not $loggedOnUser) {
        throw "Could not determine the logged-on user."
    }
    return (New-Object System.Security.Principal.NTAccount($loggedOnUser)).Translate(
             [System.Security.Principal.SecurityIdentifier]).Value
}

function Resolve-Upn {
    param([string]$Sid)
    # The AAD\Package\* glob can match multiple subkeys (multiple work/school
    # accounts). Resolve only when there is exactly one distinct UPN; if it is
    # ambiguous, return $null so the caller fails rather than guessing an email.
    $upns = @((Get-ItemProperty "Registry::HKEY_USERS\$Sid\SOFTWARE\Microsoft\Windows\CurrentVersion\AAD\Package\*" `
              -ErrorAction SilentlyContinue).Username | Where-Object { $_ } | Select-Object -Unique)

    if ($upns.Count -eq 0) {
        $upns = @((Get-ItemProperty "Registry::HKEY_USERS\$Sid\SOFTWARE\Microsoft\Office\16.0\Common\Identity" `
                  -ErrorAction SilentlyContinue).ADUserName | Where-Object { $_ } | Select-Object -Unique)
    }

    if ($upns.Count -ne 1) {
        return $null
    }
    return $upns[0]
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
        $userSid = Resolve-LoggedOnUserSid
        Write-Output "Logged-on user SID: [$userSid]"
    }

    if ($setEmployeeEmail -and $EmployeeEmail -eq "AUTO") {
        $resolvedEmail = Resolve-Upn -Sid $userSid
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
