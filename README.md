# Oveo Agent Installer Scripts

Scripts to install Oveo Desktop Agent

## MacOS

Installation with specified Oveo customer key:

```sh
OVEO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/oveo-io/agent-installer-scripts/main/macos.install.sh)"
```

Installation with specified Oveo customer key and Employee email of computer:

```sh
OVEO_CUSTOMER_KEY="SPECIFY_CUSTOMER_KEY_HERE" OVEO_EMPLOYEE_EMAIL="SPECIFY_EMPLOYEE_EMAIL_HERE" bash -c "$(curl -L https://raw.githubusercontent.com/oveo-io/agent-installer-scripts/main/macos.install.sh)"
```

## Windows

Installation with specified Oveo customer key:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/oveo-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE")
```

Installation with specified Oveo customer key and Employee email of computer:

```powerhsell
([scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/oveo-io/agent-installer-scripts/main/windows.install.ps1'))).Invoke("SPECIFY_CUSTOMER_KEY_HERE", "SPECIFY_EMPLOYEE_EMAIL_HERE")
```
