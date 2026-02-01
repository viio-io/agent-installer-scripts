<#
.SYNOPSIS
    Remediation script for Viio browser extension customerKey.
.DESCRIPTION
    Creates registry paths and sets the customerKey value.
#>

$CustomerKey = "YOUR_CUSTOMER_KEY_HERE"

$RegistryPaths = @{
    "Chrome - Silent"   = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\nffjckgmpigfpkmamacllkakieaphfnm\policy"
    "Chrome - Standard" = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\fjambfppaeandondpbbjkggkabeccjmh\policy"
    "Edge - Silent"     = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\nffjckgmpigfpkmamacllkakieaphfnm\policy"
    "Edge - Standard"   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\fjambfppaeandondpbbjkggkabeccjmh\policy"
}

$ExitCode = 0

foreach ($Name in $RegistryPaths.Keys) {
    $Path = $RegistryPaths[$Name]

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Output "$Name - Created path"
        }
        Set-ItemProperty -Path $Path -Name "customerKey" -Value $CustomerKey -Type String -Force
        Write-Output "$Name - customerKey set successfully"
    }
    catch {
        Write-Output "$Name - Failed: $_"
        $ExitCode = 1
    }
}

exit $ExitCode
