# Service name (replace with your specific service name)
$SERVICE_NAME = "ViioDesktopAgent"

function Test-AdminPrivilege {
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

    Write-Output "Checking if $serviceName is installed..."

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Output "$serviceName is installed."
        Write-Output "`nService Status: $($service.Status)"
        Write-Output "`nStartup Type: $(Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'")"
    } else {
        Write-Output "$serviceName is not installed."
    }
}

# Function to get the folder path of a service's executable
function Get-ServiceExecutablePath {
    param (
        [string]$serviceName
    )

    # Get the service object
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'"

    if ($service) {
        # Extract the executable path from the service's executable path
        # Remove double quotes and extract the directory path
        $executablePath = $service.PathName -replace '^"(.+)"$', '$1'
        $serviceFolderPath = [System.IO.Path]::GetDirectoryName($executablePath)

        # Explicitly return the folder path
        return $serviceFolderPath
    } else {
        Write-Error "`nService '$serviceName' is not installed on this system."
        return $null
    }
}

# Function to retrieve and display information about all files in a specified directory
function Get-DirectoryFilesInfo {
    param (
        [string]$directoryPath
    )

    if (Test-Path -Path $directoryPath) {
        Write-Output "`nFiles in the directory ($directoryPath):"
        Get-ChildItem -Path "$directoryPath" -File | Select-Object Name, Length, CreationTime, LastWriteTime | Format-List
    } else {
        Write-Warning "`nDirectory not found: $directoryPath"
    }
}

# Function to print version of executable
function Get-FileVersionInfo {
    param (
        [string]$filePath
    )

    if (Test-Path -Path $filePath) {
        $fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($filePath)

        Write-Output "`nFile Version for '$filePath': $($fileVersionInfo.FileVersion)"
        Write-Output "Product Version for '$filePath': $($fileVersionInfo.ProductVersion)"
    } else {
        Write-Warning "`nFile not found: $filePath"
    }
}

# Function to read and print the content of a specified file
function Get-FileContent {
    param (
        [string]$filePath
    )

    if (Test-Path $filePath) {
        Write-Output "`nContent of the file ($filePath):"
        Get-Content -Path $filePath
    } else {
        Write-Warning "`nFile not found: $filePath"
    }
}

# Function to print content of last modified file
function Get-LatestFileContent {
    param (
        [string]$folderPath
    )

    # Get all files in the folder, sorted by LastWriteTime
    $latestFile = Get-ChildItem -Path $folderPath -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestFile) {
        Write-Output "`nDisplaying content of the latest file: $($latestFile.FullName)"
        Get-Content -Path $latestFile.FullName
    } else {
        Write-Warning "`nFiles in folder $folderPath are not found"
    }
}

# Function to test URL availability
function Test-ServiceApiAvailability {
    param (
        [string]$url
    )

    try {
        $response = Invoke-WebRequest -Uri $url -Method 'GET' -UseBasicParsing
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            Write-Output "`nAPI at $url is available. Status Code: $($response.StatusCode)"

            # Check if response content is not empty
            if ([string]::IsNullOrWhiteSpace($response.Content)) {
                Write-Warning "Response content is empty."
            } else {
                Write-Output "Response Content: $($response.Content)"
            }
        } else {
            Write-Warning "`nAPI at $url responded, but with a non-successful status code: $($response.StatusCode)"
        }
    } catch {
        Write-Warning "`nAPI at $url is not available. Error: $_"
    }
}

# Function to get service log from standard service loggin mechanism
function Get-ServiceLog {
    param (
        [string]$serviceName,
        [int]$numberOfEntries = 10 # Default to the last 10 entries
    )

    try {
        Write-Output "`nGetting event log entries for service: $serviceName"

        # Check if there are any entries for the given source
        $exists = Get-EventLog -LogName System -Source $serviceName -Newest 1 -ErrorAction SilentlyContinue
        if ($exists) {
            # Fetching entries
            $logEntries = Get-EventLog -LogName System -Source $serviceName -Newest $numberOfEntries
            foreach ($entry in $logEntries) {
                Write-Output ("[" + $entry.TimeWritten + "] " + $entry.EntryType + ": " + $entry.Message)
            }
        } else {
            Write-Output "No log entries found for service: $serviceName"
        }
    } catch {
        Write-Warning "`nError retrieving log entries: $_"
    }
}

# Function to get device id
function Get-DeviceUUID {
    $computerSystemProduct = Get-CimInstance -ClassName Win32_ComputerSystemProduct
    $uuid = $computerSystemProduct.UUID

    Write-Output "`nDevice UUID: $uuid"

    Write-Output "Machine Name: $env:COMPUTERNAME"
}

# MAINs

# Check if running as Administrator
if (-not (Test-AdminPrivilege)) {
    Write-Warning "This script is better to run as an Administrator."
}

# Check if the service is installed and its status
Confirm-ServiceInstalled -serviceName $SERVICE_NAME

# Print all files in service installation folder
$folderOfServiceExecutable = Get-ServiceExecutablePath -serviceName $SERVICE_NAME

Write-Output "`nExecutable Path for Service '$SERVICE_NAME': $folderOfServiceExecutable"

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
Get-ServiceLog -serviceName $SERVICE_NAME

# Check APIs accessibility
Test-ServiceApiAvailability -url "https://api.viio.io/employee-management/v1/employees/email/test@example.com"
Test-ServiceApiAvailability -url "https://api.viio.io/desktop/v1/settings/windows"

Write-Output "`n** SCRIPT EXECUTION DONE **"
# Ensures no value is returned in the end
return
