# Service name (replace with your specific service name)
$SERVICE_NAME = "ViioDesktopAgent"

# Function to check if the service is installed
function Confirm-ServiceInstalled {
    param (
        [string]$serviceName
    )

    Write-Host "Checking if $serviceName is installed..."
    
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "$serviceName is installed."
        Write-Host "Service Status: $($service.Status)"
        Write-Host "Startup Type: $(Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode"
    } else {
        Write-Host "$serviceName is not installed."
    }
}

Confirm-ServiceInstalled -serviceName $SERVICE_NAME

# Ensures no value is returned in the end
return
