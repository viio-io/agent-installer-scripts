param(
    [Parameter(Mandatory=$true)]
    [string]$OveoCustomerKey,

    [Parameter()]
    [string]$OveoEmployeeEmail = "null"
)

Invoke-WebRequest -Uri "https://cdn.oveo.io/desktop-agent/Oveo+Desktop+Agent+Installer+1.2.1.msi" -OutFile "./oveo-agent-installer.msi"

# & './oveo-agent-insaller.msi' /VERYSILENT /LOG /OveoCustomerKey=$OveoCustomerKey /OveoEmployeeEmail=$OveoEmployeeEmail | Out-Null
& msiexec /l*v oveo.log /i 'oveo-agent-installer.msi' /passive /qn OVEO_CUSTOMER_KEY=$OveoCustomerKey OVEO_EMPLOYEE_EMAIL=$OveoEmployeeEmail

Remove-Item "./oveo-agent-installer.msi"
