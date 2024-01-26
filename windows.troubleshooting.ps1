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

# Function to get the folder path of a service's executable
function Get-ServiceExecutablePath {
    param (
        [string]$serviceName
    )

    # Get the service object
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

    if ($service) {
        # Extract the executable path from the service's executable path
        # Remove double quotes and extract the directory path
        $executablePath = $service.PathName -replace '^"(.+)"$', '$1'
        $serviceFolderPath = [System.IO.Path]::GetDirectoryName($executablePath)

        Write-Host "Executable Path for Service '$serviceName': $executablePath"

        # Return the folder path
        return $serviceFolderPath
    } else {
        Write-Host "Service '$serviceName' is not installed on this system."
        return $null
    }
}

# Function to retrieve and display information about all files in a specified directory
function Get-DirectoryFilesInfo {
    param (
        [string]$directoryPath
    )

    Write-Host ""
    if (Test-Path -Path $directoryPath) {
        Write-Host "Files in the directory ($directoryPath):"
        Get-ChildItem -Path "$directoryPath" -File | Select-Object Name, Length, CreationTime, LastWriteTime | Format-List
    } else {
        Write-Host "Directory not found: $directoryPath" -ForegroundColor Red
    }
}

# Function to read and print the content of a specified file
function Get-FileContent {
    param (
        [string]$filePath
    )

    Write-Host ""
    if (Test-Path $filePath) {
        Write-Host "Content of the file ($filePath):" -ForegroundColor Green
        Get-Content -Path $filePath
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
    }
}

# Function to test URL availability
function Test-ServiceApiAvailability {
    param (
        [string]$url
    )

    Write-Host ""
    try {
        $response = Invoke-WebRequest -Uri $url -Method 'GET' -UseBasicParsing
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            Write-Host "API at $url is available. Status Code: $($response.StatusCode)" -ForegroundColor Green

            # Check if response content is not empty
            if ([string]::IsNullOrWhiteSpace($response.Content)) {
                Write-Host "Response content is empty." -ForegroundColor Cyan
            } else {
                Write-Host "Response Content: $($response.Content)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "API at $url responded, but with a non-successful status code: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "API at $url is not available. Error: $_" -ForegroundColor Red
    }
}

# Function to get device id
function Get-DeviceUUID {
    $computerSystemProduct = Get-WmiObject -Class Win32_ComputerSystemProduct
    $uuid = $computerSystemProduct.UUID

    Write-Host ""
    Write-Host "Device UUID: $uuid"

    # Get Machine Name
    Write-Host "Machine Name: $env:COMPUTERNAME"
}

# MAINs

# Check if running as Administrator
if (-not (Test-AdminPrivileges)) {
    Write-Host "This script is better to run as an Administrator." -ForegroundColor Red
}

# Check if the service is installed and its status
Confirm-ServiceInstalled -serviceName $SERVICE_NAME

# Print all files in service installation folder
$folderOfServiceExecutable = Get-ServiceExecutablePath -serviceName $SERVICE_NAME
Get-DirectoryFilesInfo -directoryPath $folderOfServiceExecutable

Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings-after-install.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "info.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "config.json")

# Check APIs accessibility
Test-ServiceApiAvailability -url "https://api.viio.io/employee-management/v1/employees/email/test@example.com"
Test-ServiceApiAvailability -url "https://api.viio.io/desktop/v1/settings/windows" 

## Device ID
Get-DeviceUUID

## File attribute with Version

# Ensures no value is returned in the end
return
