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
    if curl --output /dev/null --silent --get --fail "$url"; then
        echo "URL $url is accessible."
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

# Function to check if an environment variable is provided
check_env_variable() {
    local var_name=$1

    # Using indirect variable reference to get the value of the variable with name in var_name
    local var_value=${!var_name}

    echo ""
    if [ -z "$var_value" ]; then
        echo "Environment variable '$var_name' is not set or is empty."
        return 1
    else
        echo "Environment variable '$var_name' is set to '$var_value'."
        return 0
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

### MAIN

# Check if the service is installed
check_service_installed

# Check daemon status
check_daemon_status

# Check APIs accessibility
check_url_accessibility "https://api.viio.io/employee-management/v1/employees/email/test@mail.com"
check_url_accessibility "https://api.viio.io/desktop/v1/settings/test"

# List all files in the installation directory
list_files_in_directory "/usr/local/viio"

# Check globally set env variables
check_env_variable "VIIO_CUSTOMER_KEY"
check_env_variable "VIIO_EMPLOYEE_EMAIL"
check_env_variable "VIIO_INSTALLER_USER"

# Print some config files
print_file_content "/etc/viio.conf"
print_file_content "/var/log/viio_stderr.log"
print_file_content "/usr/local/viio/appsettings.json"
print_file_content "/usr/local/viio/appsettings-after-install.json"
print_file_content "/usr/local/viio/info.json"

# Getting logs from operating system
get_service_logs $SERVICE_NAME
