param(
  [Parameter(Mandatory = $true)]
  [string]$OveoCustomerKey,

  [Parameter()]
  [string]$OveoEmployeeEmail = "null"
)

$SUPPORT_EMAIL = "support@oveo.io"

Invoke-WebRequest -Uri "https://cdn.oveo.io/desktop-agent/Oveo+Desktop+Agent+Installer+1.2.1.msi" -OutFile "./oveo-agent-installer.msi"

$MSIArguments = @(
  "/i"
  "oveo-agent-installer.msi"
  "OVEO_CUSTOMER_KEY=$OveoCustomerKey"
  "OVEO_EMPLOYEE_EMAIL=$OveoEmployeeEmail"
  "/qn"
  "/passive"
  "/norestart"
  "/l*v"
  "oveo.log"
)

Start-Process "msiexec" -ArgumentList $MSIArguments -Wait -NoNewWindow

Remove-Item "./oveo-agent-installer.msi"

$ServiceStatus = (Get-Service -Name OveoDesktopAgent).Status
if ($ServiceStatus -eq "Running") {
  Write-Output "Your Agent is running properly. It will continue to run in the background and submit data to Oveo."
  Remove-Item "./oveo.log"
}
else {
  Write-Output "The Oveo Desktop Agent is not running after installation. Please contact $SUPPORT_EMAIL and send the oveo.log file for more information."
  exit 1
}
