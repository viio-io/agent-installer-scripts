param(
    [Parameter(Mandatory=$true)]
    [string]$OveoCustomerKey,

    [Parameter()]
    [string]$OveoEmployeeEmail = "null"
)

Invoke-WebRequest -Uri "https://cdn.oveo.io/desktop-agent/Oveo+Desktop+Agent-1.1.3.exe" -OutFile "./oveo-agent.exe"

& './oveo-agent.exe' /VERYSILENT /LOG /OveoCustomerKey=$OveoCustomerKey /OveoEmployeeEmail=$OveoEmployeeEmail | Out-Null

Remove-Item "./oveo-agent.exe"
