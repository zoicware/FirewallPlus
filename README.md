# Firewall+ by Zoic

This powershell script will query https://abuse.ch/ a botnet and malware database full of malicous IPs. These IPs will be added to a custom rule in Windows Firewall to block inbound and outbound connections. Abuse.ch updates
these databases every 5 mins. The script will create an updater file in the root c drive and a schd task will be created to run this updater. This will run every night at 4 am if the user is logged on. If not the task will run the next time the pc is booted.


There are services that do something very similar to this but that requires 3rd party software or a vpn with this method we can "live off the land" and just use what windows has to offer.
