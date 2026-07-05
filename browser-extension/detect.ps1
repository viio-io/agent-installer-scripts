<#
.SYNOPSIS
    Detection script for Viio browser extension registry configuration.
.DESCRIPTION
    Checks that "customerKey" (and optionally "employeeEmail") policy values are
    correctly set for the Viio browser extension in Chrome and Edge (Silent and
    Interactive editions).

    Exit 0 = Compliant (all configured values present and correct)
    Exit 1 = Non-compliant (something missing/incorrect -> remediation runs)

    IMPORTANT: The CONFIGURATION section below MUST match the paired remediation
    script (remediate.ps1). If they diverge, remediation either never runs or
    runs on every cycle.

    Scope rules mirror remediation:
      * customerKey  is REQUIRED and always checked in HKLM (machine-wide).
      * employeeEmail is optional and checked in HKLM or HKCU via $EmployeeEmailScope.

    Designed to run as SYSTEM ("Run this script using the logged-on credentials = No").
    For HKCU scope, the logged-on user's hive (HKEY_USERS\<SID>) is checked.
#>

# ============================ CONFIGURATION ============================

# Customer key. REQUIRED - must match the remediation script.
$CustomerKey = "YOUR_CUSTOMER_KEY_HERE"

# Employee email. Leave empty ("") to skip checking employeeEmail.
# Use the literal value "AUTO" to compare against the logged-on user's UPN.
$EmployeeEmail = "AUTO"

# Where employeeEmail is expected: "HKLM" (machine-wide) or "HKCU" (per logged-on user).
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

# ---- Validate configuration -------------------------------------------------

$checkEmployeeEmail = -not [string]::IsNullOrWhiteSpace($EmployeeEmail)

if ([string]::IsNullOrWhiteSpace($CustomerKey) -or $CustomerKey -eq "YOUR_CUSTOMER_KEY_HERE") {
    Write-Output "CustomerKey is required but not configured."
    exit 1
}

if ($checkEmployeeEmail -and $EmployeeEmailScope -notin @("HKLM", "HKCU")) {
    Write-Output "Invalid EmployeeEmailScope: [$EmployeeEmailScope]. Must be 'HKLM' or 'HKCU'."
    exit 1
}

# ---- Resolve per-user context (only when needed) ----------------------------

$userSid = $null
$expectedEmail = $EmployeeEmail

try {
    if ($checkEmployeeEmail -and ($EmployeeEmailScope -eq "HKCU" -or $EmployeeEmail -eq "AUTO")) {
        $userSid = Resolve-LoggedOnUserSid
    }

    if ($checkEmployeeEmail -and $EmployeeEmail -eq "AUTO") {
        $expectedEmail = Resolve-Upn -Sid $userSid
        if (-not $expectedEmail) {
            Write-Output "Non-compliant: could not resolve employeeEmail from the logged-on user's UPN."
            exit 1
        }
    }
}
catch {
    Write-Output "Non-compliant: failed to resolve user context: $_"
    exit 1
}

# ---- Check each browser/edition ---------------------------------------------

$Issues = @()

foreach ($browser in $BrowserPath.Keys) {
    foreach ($edition in $ExtensionId.Keys) {
        $label = "$browser - $edition"

        # customerKey (always HKLM)
        $hklmPath = Get-PolicyPath -Root "HKLM:" -Browser $browser -Edition $edition
        if (-not (Test-Path $hklmPath)) {
            $Issues += "$label - Path missing: $hklmPath"
        }
        else {
            $value = Get-ItemProperty -Path $hklmPath -Name "customerKey" -ErrorAction SilentlyContinue
            if ($value.customerKey -ne $CustomerKey) {
                $Issues += "$label - customerKey incorrect or missing"
            }
        }

        # employeeEmail (optional; HKLM or HKCU)
        if ($checkEmployeeEmail) {
            if ($EmployeeEmailScope -eq "HKLM") {
                $emailPath = Get-PolicyPath -Root "HKLM:" -Browser $browser -Edition $edition
            }
            else {
                $emailPath = Get-PolicyPath -Root "Registry::HKEY_USERS\$userSid" -Browser $browser -Edition $edition
            }

            if (-not (Test-Path $emailPath)) {
                $Issues += "$label - employeeEmail path missing: $emailPath"
            }
            else {
                $value = Get-ItemProperty -Path $emailPath -Name "employeeEmail" -ErrorAction SilentlyContinue
                if ($value.employeeEmail -ne $expectedEmail) {
                    $Issues += "$label - employeeEmail incorrect or missing"
                }
            }
        }
    }
}

if ($Issues.Count -gt 0) {
    $Issues | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output "All registry keys are configured correctly"
exit 0
