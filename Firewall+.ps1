
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) 
{	Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	}

$host.ui.RawUI.WindowTitle = 'Firewall+ by Zoic'


#Removing any old rules
$firewallRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -eq "Block Bad IPs"} 

if ($firewallRules) {
    foreach ($rule in $firewallRules) {
        Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
    }
  }



function Get-IPAddressesFromCSV1($csvString) {
    $ipAddresses = @()

    # Split the CSV string into lines
    $lines = $csvString -split "\r?\n"

    # Extract IP addresses
    foreach ($line in $lines) {
        # Skip empty lines and comment lines
        if ($line -notmatch "^\s*(#|$)") {
            # Extract the IP address from the appropriate field
            if ($line -match '"[^"]*","([^"]+)"') {
                $ip = $matches[1].Trim()
                $ipAddresses += $ip
            }
        }
    }
    $ipAddresses = $ipAddresses | Select-Object -Skip 1
    return $ipAddresses
}

function Get-IPAddressesFromCSV2($csvString) {
    $ipAddresses = @()

    # Split the CSV string into lines
    $lines = $csvString -split "\r?\n"

    # Extract IP addresses
    foreach ($line in $lines) {
        # Skip empty lines and comment lines
        if ($line -notmatch "^\s*(#|$)") {
            # Extract the IP address from the appropriate field
            if ($line -match 'http://([\d.]+):') {
                $ip = $matches[1].Trim()
                $ipAddresses += $ip
            }
        }
    }

    return $ipAddresses
}


# Function to create a firewall rule to block multiple IP addresses
function New-FirewallRule($ipAddresses, $direction) {
    $action = "Block"
    $ruleName = "Block Bad IPs"

    

    # Create the rule
    $rule = New-NetFirewallRule -DisplayName $ruleName -Direction $direction -LocalPort Any -Protocol Any -Action $action -RemoteAddress $ipAddresses -Enabled True -Profile Any -Description "Blocking multiple IP addresses"

    # Apply the rule immediately
    $rule | Set-NetFirewallRule -PassThru
}

# URLs to query
$url1 = "https://feodotracker.abuse.ch/downloads/ipblocklist.csv"
$url2 = "https://urlhaus.abuse.ch/downloads/csv_online/"

# Query the URLs and get the CSV content
$csvContent1 = Invoke-WebRequest -Uri $url1 -UseBasicParsing | Select-Object -ExpandProperty Content 
$csvContent2 = Invoke-WebRequest -Uri $url2 -UseBasicParsing | Select-Object -ExpandProperty Content 

# Extract IP addresses from CSV content
$ipAddresses1 = Get-IPAddressesFromCSV1 $csvContent1
$ipAddresses2 = Get-IPAddressesFromCSV2 $csvContent2



# Create inbound and outbound rules for CSV content 1
New-FirewallRule $ipAddresses1 "Inbound"
New-FirewallRule $ipAddresses1 "Outbound"

# Create inbound and outbound rules for CSV content 2
New-FirewallRule $ipAddresses2 "Inbound"
New-FirewallRule $ipAddresses2 "Outbound"


#Creating updater file
$url = "https://raw.githubusercontent.com/zoicware/FirewallUpdater/main/FirewallUpdater.ps1"
$content = Invoke-WebRequest -Uri $url -UseBasicParsing 
New-Item -Path "C:\FirewallUpdater.ps1" -Force
Set-Content -Path "C:\FirewallUpdater.ps1" -Value $content



#create schd task to run updater at 4am everyday and if not ran then run when the pc starts


$taskName = "FirewallUpdater"
$actionScript = "C:\FirewallUpdater.ps1"

# Check if the task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask -eq $null) {
    # Create a new scheduled task
    $trigger = New-ScheduledTaskTrigger -Daily -At 4am
    $trigger.StartBoundary = ([datetime]::Today.AddDays(1).Date + [TimeSpan]::FromHours(4)).ToString("yyyy-MM-ddTHH:mm:ss")
    $trigger.ExecutionTimeLimit = "PT15M" 
    $trigger.Enabled = $true
    
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$actionScript`""
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -RunLevel Highest
    Write-Host "Scheduled task created successfully."
} else {
    Write-Host "Scheduled task already exists."
}

