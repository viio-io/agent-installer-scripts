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
        Write-Warning "$serviceName is not installed."
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
        Write-Warning "`nService '$serviceName' is not installed on this system."
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

    try {
        if (Test-Path $filePath) {
            Write-Output "`nContent of the file ($filePath):"
            Get-Content -Path $filePath
        } else {
            Write-Warning "`nFile not found: $filePath"
        }
    } catch {
        Write-Warning "`nFailed to get file content"
    }
}

# Function to print content of last modified file
function Get-LatestFileContent {
    param (
        [string]$folderPath
    )
    try {
        # Get all files in the folder, sorted by LastWriteTime
        $latestFile = Get-ChildItem -Path $folderPath -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestFile) {
            Write-Output "`nDisplaying content of the latest file: $($latestFile.FullName)"
            Get-Content -Path $latestFile.FullName
        } else {
            Write-Warning "`nFiles in folder $folderPath are not found"
        }
    } catch {
        Write-Warning "`nFailed to get latest file content"
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
                Write-Warning "Response content is empty of url: $url."
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

# Function to get user info
function Get-UserInfo {
    $username = [System.Environment]::UserName
    $userdomain = [System.Environment]::UserDomainName

    Write-Output "`nUser Name: $username"
    Write-Output "User Domain: $userdomain"
}

function Get-Registry {

    Write-Output "`nChecking registry..."

    $displayNameFragment = "Viio"          # what to match in DisplayName

    # -- registry hives to search -------------------------------------------------
    $registryPaths = @(
        # 1. Machine-wide (64-bit view)
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        # 2. Machine-wide (32-bit view on 64-bit OS)
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",

        # 3. Per-user (current logged-on user, 64-bit view)
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        # 4. Per-user (current logged-on user, 32-bit view on 64-bit OS)
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    # 5. Per-user **for every loaded profile** (useful on multi-user servers)
    Get-ChildItem HKU:\ -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^HKEY_USERS\\S-\d-\d+-.+' } |   # only SIDs# keep only SIDs
        ForEach-Object {
            $sid = $_.PSChildName
            $registryPaths += "HKU:\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            $registryPaths += "HKU:\$sid\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        }
    # ----------------------------------------------------------------------

    foreach ($path in $registryPaths) {

        Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {

            $keyPath = $_.PSPath
            $props   = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue

            # skip if no DisplayName or if it doesn't contain "Viio"
            if ($null -ne $props.DisplayName -and
                $props.DisplayName -like "*$displayNameFragment*")
            {
                # ----- full dump (every name/value on its own line) -------------
                Write-Output "`n[$keyPath]" -ForegroundColor Cyan
                $props.PSObject.Properties |
                    Sort-Object Name |
                    ForEach-Object {
                        Write-Output ("{0} : {1}" -f $_.Name, $_.Value)
                    }
            }
        }
    }

    Write-Output "`nRegistry check finished"
}

# MAINs

# Check if running as Administrator
if (-not (Test-AdminPrivilege)) {
    Write-Warning "This script is better to run as an Administrator."
}

# Check if the service is installed and its status
Confirm-ServiceInstalled -serviceName $SERVICE_NAME

Get-Registry

# Print all files in service installation folder
$folderOfServiceExecutable = Get-ServiceExecutablePath -serviceName $SERVICE_NAME

if ($folderOfServiceExecutable) {
    try {
        Write-Output "`nExecutable Path for Service '$SERVICE_NAME': $folderOfServiceExecutable"

        Get-FileVersionInfo -filePath (Join-Path $folderOfServiceExecutable "DesktopAgent.Windows.exe")

        Get-DirectoryFilesInfo -directoryPath $folderOfServiceExecutable

        Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings.json")
        Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "appsettings-after-install.json")
        Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "info.json")
        Get-FileContent -filePath (Join-Path $folderOfServiceExecutable "config.json")

        # Print latest log file
        Get-LatestFileContent -folderPath (Join-Path $folderOfServiceExecutable "logs")
    } catch {
        Write-Warning "`nFailed to get agent files"
    }
}
## Device ID
Get-DeviceUUID

## Logged User Info
Get-UserInfo

# Get OS standart service log messages
Get-ServiceLog -serviceName $SERVICE_NAME

# Check APIs accessibility
Test-ServiceApiAvailability -url "https://api.viio.io/employee-management/v1/employees/email/test@example.com"
Test-ServiceApiAvailability -url "https://api.viio.io/desktop/v1/settings/windows"

Write-Output "`n** SCRIPT EXECUTION DONE **"
# Ensures no value is returned in the end
return
