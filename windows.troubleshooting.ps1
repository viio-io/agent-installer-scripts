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

# Function to print version of executable
function Get-FileVersionInfo {
    param (
        [string]$filePath
    )

    Write-Host ""
    if (Test-Path -Path $filePath) {
        $fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($filePath)

        Write-Host "File Version for '$filePath': $($fileVersionInfo.FileVersion)"
        Write-Host "Product Version for '$filePath': $($fileVersionInfo.ProductVersion)"
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
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

# Function to print content of last modified file
function Get-LatestFileContent {
    param (
        [string]$folderPath
    )

    # Get all files in the folder, sorted by LastWriteTime
    $latestFile = Get-ChildItem -Path $folderPath -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    Write-Host ""
    if ($latestFile) {
        Write-Host "Displaying content of the latest file: $($latestFile.FullName)"
        Get-Content -Path $latestFile.FullName
    } else {
        Write-Host "Files in folder $folderPath are not found" -ForegroundColor Red
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

# Function to get service log from standard service loggin mechanism
function Get-ServiceLogMessages {
    param (
        [string]$serviceName,
        [int]$numberOfEntries = 10 # Default to the last 10 entries
    )

    Write-Host ""
    try {
        Write-Host "Getting event log entries for service: $serviceName"

        # Check if there are any entries for the given source
        $exists = Get-EventLog -LogName System -Source $serviceName -Newest 1 -ErrorAction SilentlyContinue
        if ($exists) {
            # Fetching entries
            $logEntries = Get-EventLog -LogName System -Source $serviceName -Newest $numberOfEntries
            foreach ($entry in $logEntries) {
                Write-Host ("[" + $entry.TimeWritten + "] " + $entry.EntryType + ": " + $entry.Message)
            }
        } else {
            Write-Host "No log entries found for service: $serviceName"
        }
    } catch {
        Write-Host "Error retrieving log entries: $_" -ForegroundColor Red
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

Get-FileVersionInfo -filePath (Join-Path $folderOfServiceExecutable "DesktopAgent.Windows.exe")

Get-DirectoryFilesInfo -directoryPath $folderOfServiceExecutable

Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings-after-install.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "info.json")
Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "config.json")

# Print latest log file
Get-LatestFileContent -folderPath (Join-Path $folderOfServiceExecutable "logs")

## Device ID
Get-DeviceUUID

# Get OS standart service log messages
Get-ServiceLogMessages -serviceName $SERVICE_NAME

# Check APIs accessibility
Test-ServiceApiAvailability -url "https://api.viio.io/employee-management/v1/employees/email/test@example.com"
Test-ServiceApiAvailability -url "https://api.viio.io/desktop/v1/settings/windows"

Write-Host ""
Write-Host "** SCRIPT EXECUTION DONE **"
# Ensures no value is returned in the end
return
