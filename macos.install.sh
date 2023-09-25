#!/bin/bash
set -e

# Environment variables:
# VIIO_CUSTOMER_KEY
# VIIO_EMPLOYEE_EMAIL

PKG_URL="https://cdn.oveo.io/desktop-agent/viio-agent-1.4.0.pkg"
# Checksum needs to be updated when PKG_URL is updated.
CHECKSUM="caa0b04b1ff353757f47b522b6a8e6a2405faf48095d96ab4b318bd79c7eb05f"
SUPPORT_EMAIL="support@viio.io"
DEVELOPER_ID="Oveo ApS (895LF9A7K6)"
CERT_SHA_FINGERPRINT="D6B409F777DC4F2D2C738EF021E40CD2286A9D8F3EA83ACFE3D2D449C53AE3A2"
PKG_PATH="$(mktemp -d)/viio-agent.pkg"
VIIO_CONF_PATH="/etc/viio.conf"

##
# Viio Agent needs to be installed as root; use sudo if not already uid 0
##
if [ "$UID" = "0" ]; then
    SUDO=''
else
    SUDO='sudo -E'
fi

if [ -z "$VIIO_CUSTOMER_KEY" ]; then
    printf "\033[31m
You must specify the VIIO_CUSTOMER_KEY environment variable in order to install the agent.
\n\033[0m\n"
    exit 1
fi


function onerror() {
    printf "\033[31m%s
Something went wrong while installing the Viio Desktop Agent.
If you're having trouble installing, please send an email to %s, and we'll help you fix it!
\n\033[0m\n" "$ERROR_MESSAGE" "$SUPPORT_EMAIL"
}
trap onerror ERR


##
# Download the agent
##
printf "\033[34m\n* Downloading the Viio Desktop Agent\n\033[0m"
rm -f "$PKG_PATH"
curl --progress-bar $PKG_URL > "$PKG_PATH"

##
# Checksum
##
printf "\033[34m\n* Ensuring checksums match\n\033[0m"
downloaded_checksum=$(shasum -a256 "$PKG_PATH" | cut -d" " -f1)
if [ "$downloaded_checksum" = $CHECKSUM ]; then
    printf "\033[34mChecksums match.\n\033[0m"
else
    printf "\033[31m Checksums do not match. Please contact %s \033[0m\n" "$SUPPORT_EMAIL"
    exit 1
fi

##
# Check Developer ID
##
printf "\033[34m\n* Ensuring package Developer ID matches\n\033[0m"

if pkgutil --check-signature "$PKG_PATH" | grep -q "$DEVELOPER_ID"; then
    printf "\033[34mDeveloper ID matches.\n\033[0m"
else
    printf "\033[31m Developer ID does not match. Please contact %s \033[0m\n" "$SUPPORT_EMAIL"
    exit 1
fi

##
# Check Developer Certificate Fingerprint
##
printf "\033[34m\n* Ensuring package Developer Certificate Fingerprint matches\n\033[0m"
if pkgutil --check-signature "$PKG_PATH" | tr -d '\n' | tr -d ' ' | grep -q "SHA256Fingerprint:$CERT_SHA_FINGERPRINT"; then
    printf "\033[34mDeveloper Certificate Fingerprint matches.\n\033[0m"
else
    printf "\033[31m Developer Certificate Fingerprint does not match. Please contact %s \033[0m\n" "$SUPPORT_EMAIL"
    exit 1
fi

##
# Install the agent
##
printf "\033[34m\n* Installing the Viio Desktop Agent. You might be asked for your password...\n\033[0m"

CONFIG="{\"CustomerKey\":\"$VIIO_CUSTOMER_KEY\",\"EmployeeEmail\":\"$VIIO_EMPLOYEE_EMAIL\"}"
echo "$CONFIG" | $SUDO tee "$VIIO_CONF_PATH" > /dev/null
$SUDO /bin/chmod 400 "$VIIO_CONF_PATH"
$SUDO /usr/sbin/chown root:wheel "$VIIO_CONF_PATH"

$SUDO /usr/sbin/installer -pkg "$PKG_PATH" -target / >/dev/null

rm -f "$PKG_PATH"

##
# check if the agent is running
##
if launchctl print system/io.viio.agent.metalauncher | grep -q "state = running"; then
    printf "\033[32mYour Agent is running properly. It will continue to run in the background and submit data to Viio.\033[0m"
else
    printf "\033[31m The Viio Desktop Agent is not running after installation. Please contact %s \033[0m\n" "$SUPPORT_EMAIL"
    exit 1
fi
