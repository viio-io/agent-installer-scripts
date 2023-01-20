# Oveo Agent Installer Scripts

Scripts to install Oveo Desktop Agent

## MacOS

Installation with specified Oveo customer key:

```sh
OVEO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.install.sh)"
```

Installation with specified Oveo customer key and Employee email of computer:

```sh
OVEO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" OVEO_EMPLOYEE_EMAIL="SPECIFY_EMPLOYEE_EMAIL_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.install.sh)"
```

To uninstall the agent, run the following commands:

```shell
sudo launchctl remove com.oveo.agent.metalauncher
sudo rm /Library/LaunchDaemons/io.oveo.agent.metalauncher.plist
sudo rm -rf /usr/local/oveo
sudo rm /etc/oveo.conf
```

## Windows

### Using Powershell

Installation with specified Oveo customer key:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE")
```

Installation with specified Oveo customer key and Employee email of computer:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE", "SPECIFY_EMPLOYEE_EMAIL_HERE")
```

## Using cmd

Some MDM solutions doesn't not allow to execute powershell scripts or fresh Windows 10 install can have strict policy for executing powershell scripts.
In that case the cmd script can be used:

```cmd
@echo off
SETLOCAL
SET email=%1
@powershell -ExecutionPolicy Bypass -Command "([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1')).Invoke('SPECIFY_CUSTOMER_KEY_HERE', '%email%'))"
ENDLOCAL
```

> *NOTE:* `SET email=%1` means that email will be passed to script by MDM solution as the 1st argument, e.g., `script.cmd test@example.com`. If the email is passed as the 2nd argument, the line will look `SET email=%2` and so on for 3rd, 4th, etc. order of argument.
