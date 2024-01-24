param(
  [Parameter(Mandatory = $true)]
  [string]$CustomerKey,

  [Parameter()]
  [string]$EmployeeEmail = "null"
)

$SUPPORT_EMAIL = "support@viio.io"

Invoke-WebRequest -Uri "https://cdn.oveo.io/desktop-agent/Viio_Desktop_Agent_Installer_1.4.2.msi" -OutFile "./viio-agent-installer.msi"

$MSIArguments = @(
  "/i"
  "viio-agent-installer.msi"
  "VIIO_CUSTOMER_KEY=$CustomerKey"
  "VIIO_EMPLOYEE_EMAIL=$EmployeeEmail"
  "/qn"
  "/passive"
  "/norestart"
  "/l*v"
  "viio.log"
)

Start-Process "msiexec" -ArgumentList $MSIArguments -Wait -NoNewWindow

Remove-Item "./viio-agent-installer.msi"

$ServiceStatus = (Get-Service -Name ViioDesktopAgent).Status
if ($ServiceStatus -eq "Running") {
  Write-Output "Your Agent is running properly. It will continue to run in the background and submit data to Viio."
  Remove-Item "./viio.log"
}
else {
  Write-Output "The Viio Desktop Agent is not running after installation. Please contact $SUPPORT_EMAIL and send the viio.log file for more information."
  exit 1
}
