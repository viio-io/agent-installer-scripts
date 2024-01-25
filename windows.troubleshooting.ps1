# Service name (replace with your specific service name)
$SERVICE_NAME = "ViioDesktopAgent"

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    return $windowsPrincipal.IsInRole($adminRole)
}

# Function to check if the service is installed and its status
function Confirm-ServiceInstalled {
    param (
        [string]$serviceName
    )

    Write-Host "Checking if $serviceName is installed..."
    
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "$serviceName is installed."
        Write-Host ""
        Write-Host "Service Status: $($service.Status)"
        Write-Host ""
        Write-Host "Startup Type: $(Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode"
    } else {
        Write-Host "$serviceName is not installed."
    }
}

# Function to print all files in service installation folder
function Get-ServiceInstallFolderAndFiles {
    param (
        [string]$serviceName
    )

    # Get the service object
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

    Write-Host ""
    if ($service) {
        # Extract the executable path from the service's executable path
        # Remove double quotes and extract the directory path
        $executablePath = $service.PathName -replace '^"(.+)"$', '$1'
        $serviceFolderPath = [System.IO.Path]::GetDirectoryName($executablePath)

        Write-Host "Executable Path for Service '$serviceName': $executablePath"
        Write-Host ""
        Write-Host "Files in the folder of the executable:"

        # Get and list all files in the directory with details
        Get-ChildItem -Path $serviceFolderPath -File | Select-Object Name, Length, CreationTime, LastWriteTime | Format-List
    } else {
        Write-Host "Service '$serviceName' is not installed on this system."
    }
}

function Test-ServiceApiAvailability {
    param (
        [string]$url
    )

    try {
        $response = Invoke-WebRequest -Uri $url -Method 'GET' -UseBasicParsing
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            Write-Host "API at $url is available. Status Code: $($response.StatusCode)" -ForegroundColor Green
        } else {
            Write-Host "API at $url responded, but with a non-successful status code: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "API at $url is not available. Error: $_" -ForegroundColor Red
    }
}

# MAINs

# Check if running as Administrator
if (-not (Test-AdminPrivileges)) {
    Write-Host "This script is better to run as an Administrator." -ForegroundColor Red
}

# Check if the service is installed and its status
Confirm-ServiceInstalled -serviceName $SERVICE_NAME

# Print all files in service installation folder
Get-ServiceInstallFolderAndFiles -serviceName $SERVICE_NAME

# Check APIs accessibility
Test-ServiceApiAvailability -url "https://api.viio.io/employee-management/v1/employees/email/test@mail.com"
Test-ServiceApiAvailability -url "https://api.viio.io/desktop/v1/settings/test"

# Ensures no value is returned in the end
return
