<#
.SYNOPSIS
    Detection script for Viio browser extension customerKey.
.DESCRIPTION
    Checks if customerKey registry value is set for Chrome and Edge.
    Exit 0 = Compliant (key exists)
    Exit 1 = Non-compliant (key missing, remediation needed)
#>

$CustomerKey = "YOUR_CUSTOMER_KEY_HERE"

$RegistryPaths = @{
    "Chrome - Silent"   = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\nffjckgmpigfpkmamacllkakieaphfnm\policy"
    "Chrome - Standard" = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\fjambfppaeandondpbbjkggkabeccjmh\policy"
    "Edge - Silent"     = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\nffjckgmpigfpkmamacllkakieaphfnm\policy"
    "Edge - Standard"   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\fjambfppaeandondpbbjkggkabeccjmh\policy"
}

$Issues = @()

foreach ($Name in $RegistryPaths.Keys) {
    $Path = $RegistryPaths[$Name]

    if (-not (Test-Path $Path)) {
        $Issues += "$Name - Path missing: $Path"
        continue
    }

    $Value = Get-ItemProperty -Path $Path -Name "customerKey" -ErrorAction SilentlyContinue

    if ($Value.customerKey -ne $CustomerKey) {
        $Issues += "$Name - customerKey incorrect or missing"
    }
}

if ($Issues.Count -gt 0) {
    $Issues | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output "All registry keys are configured correctly"
exit 0
