# Viio Agent Installer Scripts

Scripts to install the Viio Desktop Agent

## MacOS

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

## Windows

### Using PowerShell

Installation with specified Viio customer key:

```powershell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE")
```

Installation with specified Viio customer key and Employee email of computer:

```powershell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE", "SPECIFY_EMPLOYEE_EMAIL_HERE")
```

## Using cmd

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

## Browser Extension (Windows)

The `browser-extension` folder contains a paired **detection** and **remediation**
script for configuring the Viio browser extension policy on Windows via an MDM
(e.g. Intune Proactive Remediations). They set the extension's `customerKey` and,
optionally, `employeeEmail` registry values for Chrome and Edge (both the Silent
and Interactive extension editions).

| Script | Purpose |
| --- | --- |
| `browser-extension/detect.ps1` | Reports compliant (exit 0) / non-compliant (exit 1) |
| `browser-extension/remediate.ps1` | Creates the registry keys and sets the values |

### Configuration

Both scripts have a `CONFIGURATION` section at the top. **The values must be
identical in both scripts** — the detection script decides whether remediation
runs, so a mismatch means the change is either never applied or reapplied every
cycle.

| Setting | Description |
| --- | --- |
| `$CustomerKey` | **Required.** Always written to `HKLM` (machine-wide) for every browser/edition. |
| `$EmployeeEmail` | Optional. Leave empty (`""`) to skip. Set a literal email, or `"AUTO"` to derive it from the logged-on user's UPN. |
| `$EmployeeEmailScope` | `"HKLM"` (machine-wide) or `"HKCU"` (per logged-on user) for `employeeEmail`. |

### Intune settings

Deploy as a Proactive Remediation with the detection and remediation scripts
above and the following settings:

- **Run this script using the logged-on credentials:** No (runs as SYSTEM)
- **Enforce script signature check:** No
- **Run script in 64-bit PowerShell:** Yes

> *NOTE:* Because the scripts run as SYSTEM, `HKCU`-scoped `employeeEmail` is
> written into the logged-on user's registry hive (`HKEY_USERS\<SID>`), not
> SYSTEM's own `HKCU`.

## Troubleshooting

To check Agent installation we've prepared troubleshooting script for each supported OS.

### MacOS script

Run script `macos.troubleshooting.sh` and check console output:

```sh
bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.troubleshooting.sh)"
```

To share the output with the Viio dev team, please save standard and error outputs into a file using `&>` for redirection:

```sh
bash -c "$(curl -L https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/macos.troubleshooting.sh)" &> result.txt
```

### Windows script

Run script `windows.troubleshooting.ps1` in PowerShell opened with Administrator privileges and check console output:

```powershell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.troubleshooting.ps1'))).Invoke()
```

To share the output with the Viio dev team, please save standard and error outputs into a file using `*>` for redirection:

```powershell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/viio-io/agent-installer-scripts/main/windows.troubleshooting.ps1'))).Invoke() *> "result.txt"
```
