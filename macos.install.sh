#!/bin/bash
set -e

# Environment variables:
# OVEO_CUSTOMER_KEY
# OVEO_EMPLOYEE_EMAIL

PKG_URL="https://cdn.oveo.io/desktop-agent/oveo-agent-1.2.2.pkg"
# Checksum needs to be updated when PKG_URL is updated.
CHECKSUM="79261422843e2a333fedc83417063991facac17de1b1655a6af6e3704b148272"
SUPPORT_EMAIL="support@oveo.io"
DEVELOPER_ID="Oveo ApS (895LF9A7K6)"
CERT_SHA_FINGERPRINT="D6B409F777DC4F2D2C738EF021E40CD2286A9D8F3EA83ACFE3D2D449C53AE3A2"
PKG_PATH="$(mktemp -d)/oveo-agent.pkg"

##
# Oveo needs to be installed as root; use sudo if not already uid 0
##
if [ $(echo "$UID") = "0" ]; then
    SUDO=''
else
    SUDO='sudo -E'
fi

if [ -z "$OVEO_CUSTOMER_KEY" ]; then
    printf "\033[31m
You must specify the OVEO_CUSTOMER_KEY environment variable in order to install the agent.
\n\033[0m\n"
    exit 1
fi


function onerror() {
    printf "\033[31m$ERROR_MESSAGE
Something went wrong while installing the Oveo Desktop Agent.
If you're having trouble installing, please send an email to $SUPPORT_EMAIL, and we'll help you fix it!
\n\033[0m\n"
    $SUDO launchctl unsetenv OVEO_CUSTOMER_KEY
    $SUDO launchctl unsetenv OVEO_EMPLOYEE_EMAIL
}
trap onerror ERR


##
# Download the agent
##
printf "\033[34m\n* Downloading the Oveo Desktop Agent\n\033[0m"
rm -f $PKG_PATH
curl --progress-bar $PKG_URL > $PKG_PATH

##
# Checksum
##
printf "\033[34m\n* Ensuring checksums match\n\033[0m"
downloaded_checksum=$(shasum -a256 $PKG_PATH | cut -d" " -f1)
if [ $downloaded_checksum = $CHECKSUM ]; then
    printf "\033[34mChecksums match.\n\033[0m"
else
    printf "\033[31m Checksums do not match. Please contact $SUPPORT_EMAIL \033[0m\n"
    exit 1
fi

##
# Check Developer ID
##
printf "\033[34m\n* Ensuring package Developer ID matches\n\033[0m"

if pkgutil --check-signature $PKG_PATH | grep -q "$DEVELOPER_ID"; then
    printf "\033[34mDeveloper ID matches.\n\033[0m"
else
    printf "\033[31m Developer ID does not match. Please contact $SUPPORT_EMAIL \033[0m\n"
    exit 1
fi

##
# Check Developer Certificate Fingerprint
##
printf "\033[34m\n* Ensuring package Developer Certificate Fingerprint matches\n\033[0m"
if pkgutil --check-signature $PKG_PATH | tr -d '\n' | tr -d ' ' | grep -q "SHA256Fingerprint:$CERT_SHA_FINGERPRINT"; then
    printf "\033[34mDeveloper Certificate Fingerprint matches.\n\033[0m"
else
    printf "\033[31m Developer Certificate Fingerprint does not match. Please contact $SUPPORT_EMAIL \033[0m\n"
    exit 1
fi

##
# Install the agent
##
printf "\033[34m\n* Installing the Oveo Desktop Agent. You might be asked for your password...\n\033[0m"
$SUDO launchctl setenv OVEO_CUSTOMER_KEY "$OVEO_CUSTOMER_KEY"
$SUDO launchctl setenv OVEO_EMPLOYEE_EMAIL "$OVEO_EMPLOYEE_EMAIL"
$SUDO /usr/sbin/installer -pkg $PKG_PATH -target / >/dev/null
$SUDO launchctl unsetenv OVEO_CUSTOMER_KEY
$SUDO launchctl unsetenv OVEO_EMPLOYEE_EMAIL
rm -f $PKG_PATH

##
# check if the agent is running
##
if launchctl print system/com.oveo.agent.metalauncher | grep -q "state = running"; then
    printf "\033[32mYour Agent is running properly. It will continue to run in the background and submit data to Oveo.\033[0m"    
else
    printf "\033[31m The Oveo Desktop Agent is not running after installation. Please contact $SUPPORT_EMAIL \033[0m\n"
    exit 1
fi
