# Viio Agent Installer Scripts

Scripts to install the Viio Desktop Agent


## Installation

### MacOS

Installation with specified Viio customer key:

```sh
VIIO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.install.sh)"
```

Installation with specified Viio customer key and Employee email of computer:

```sh
VIIO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" VIIO_EMPLOYEE_EMAIL="SPECIFY_EMPLOYEE_EMAIL_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.install.sh)"
```

To uninstall the agent, run the following commands:

```shell
sudo launchctl remove io.viio.agent.metalauncher
sudo rm /Library/LaunchDaemons/io.viio.agent.metalauncher.plist
sudo rm -rf /usr/local/viio
sudo rm /etc/viio.conf
```

### Windows

#### Using Powershell

Installation with specified Viio customer key:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE")
```

Installation with specified Viio customer key and Employee email of computer:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE", "SPECIFY_EMPLOYEE_EMAIL_HERE")
```

### Using cmd

Some MDM solutions do not allow executing PowerShell scripts or fresh Windows 10 install can have a strict policy for executing PowerShell scripts.
In that case, the cmd script can be used:

```cmd
@echo off
SETLOCAL
SET email=%1
@powershell -ExecutionPolicy Bypass -Command "([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1')).Invoke('SPECIFY_CUSTOMER_KEY_HERE', '%email%'))"
ENDLOCAL
```

> *NOTE:* `SET email=%1` means that email will be passed to script by MDM solution as the 1st argument, e.g., `script.cmd test@example.com`. If the email is passed as the 2nd argument, the line will look `SET email=%2` and so on for 3rd, 4th, etc. order of argument.


## Version update

To update agent version you sould:
* Set new version for [Windows](https://github.com/viio-io/agent-installer-scripts/blob/main/windows.install.ps1#L11).
* Set new version for [MacOS](https://github.com/viio-io/agent-installer-scripts/blob/main/macos.install.sh#L8).
* Set new hash for [MacOS](https://github.com/viio-io/agent-installer-scripts/blob/main/macos.install.sh#L10).
	* Hash is calculated during [MacOS installer publish workflow](https://github.com/viio-io/desktop-agent/actions/workflows/publish-macos-installer.yml)