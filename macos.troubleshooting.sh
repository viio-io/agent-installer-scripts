#!/bin/bash

# Service name (you should replace this with your specific service name)
SERVICE_NAME="io.viio.agent.metalauncher"

# Check if the script is running with sudo
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Function to check if the service is installed and print the directory
check_service_installed() {
    echo "Checking if $SERVICE_NAME is installed..."

    if [ -f /Library/LaunchDaemons/$SERVICE_NAME.plist ]; then
        echo "$SERVICE_NAME is installed in /Library/LaunchDaemons/"
    elif [ -f ~/Library/LaunchAgents/$SERVICE_NAME.plist ]; then
        echo "$SERVICE_NAME is installed in ~/Library/LaunchAgents/"
    else
        echo "$SERVICE_NAME is not installed."
    fi
}

# Function to check if the service is loaded (running) and display its status
check_daemon_status() {
    echo ""
    echo "Checking if $SERVICE_NAME is running..."
    if launchctl list | grep -q $SERVICE_NAME; then
        echo "$SERVICE_NAME is running."
    else
        echo "$SERVICE_NAME is not running."
    fi

    echo ""
    echo "Service status:"
    launchctl list | grep $SERVICE_NAME
}

# Function to check if a URL is accessible
check_url_accessibility() {
    echo ""
    local url=$1
    local response=$(curl --silent --fail "$url")

    if [ $? -eq 0 ]; then
        echo "URL $url is accessible."
        if [ -z "$response" ]; then
            echo "Response content is empty."
        else
            echo "Response content:"
            echo "$response"
        fi
    else
        echo "URL $url is not accessible."
    fi
}

# Function to list all files in an installation directory
list_files_in_directory() {
    local install_folder=$1

    echo ""
    if [ -d "$install_folder" ]; then
        echo "Listing files in $install_folder:"
        ls -l "$install_folder"
    else
        echo "Directory $install_folder does not exist."
    fi
}

# Function to check if a file exists and print its content
print_file_content() {
    local file_path=$1

    echo ""
    if [ -f "$file_path" ]; then
        echo "File exists: $file_path"
        echo "Content of $file_path:"
        cat "$file_path"
    else
        echo "File does not exist: $file_path"
        return 1
    fi
}

# Function to retrieve logs for a service using the Unified Logging System
get_service_logs() {
    local service_name=$1
    local time_span=${2:-1h}  # Default time span is last 1 hour, can be overridden

    echo ""
    echo "Retrieving logs for $service_name for the past $time_span..."

    # Using the log command to filter logs based on the service name
    # Adjust the predicate according to your service's logging subsystem or other criteria
    log show --predicate "(subsystem == '$service_name' OR process == '$service_name')" --info --last $time_span --debug
}

# Function to generate DeviceID combining System Drive Serial Number and Platform Serial Number
print_device_id() {
    echo ""

    local system_drive_serial=$(system_profiler SPSerialATADataType | sed -En 's/.*Serial Number: ([\\d\\w]*)//p')

    echo "System drive serial number: $system_drive_serial"

    local platform_serial=$(ioreg -l | grep IOPlatformSerialNumber | sed 's/.*= //' | sed 's/\"//g')

    echo "Platform serial number: $platform_serial"
}

### MAIN

# Check if the service is installed
check_service_installed

# Check daemon status
check_daemon_status

# Check APIs accessibility
check_url_accessibility "https://api.viio.io/employee-management/v1/employees/email/test@example.com"
check_url_accessibility "https://api.viio.io/desktop/v1/settings/macos"

# List all files in the installation directory
list_files_in_directory "/usr/local/viio"

# Print some config files
print_file_content "/etc/viio.conf"
print_file_content "/var/log/viio_stderr.log"
print_file_content "/usr/local/viio/appsettings.json"
print_file_content "/usr/local/viio/appsettings-after-install.json"
print_file_content "/usr/local/viio/info.json"

# Getting logs from operating system
get_service_logs $SERVICE_NAME

# Print Device Id parts
print_device_id

echo ""
echo "** SCRIPT EXECUTION DONE **"
