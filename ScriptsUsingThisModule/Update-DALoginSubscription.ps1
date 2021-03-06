<#
.SYNOPSIS
	Updates the XPATH query on an event subscription used to monitor logins for Domain Admins.

.NOTES
	This script uses EventSubscriptions.psm1 module, and requires that the event subscription is already created.
	We are only updating the XPATH query for the subscription here.
#>

# Import the Event Subscriptions module
Import-Module EventSubscriptions

# Initialize DirectorySearcher Object to query AD
$Searcher = New-Object System.DirectoryServices.DirectorySearcher

# Set filter for LDAP query
$Searcher.Filter = "(&(ObjectClass=Group)(CN=Domain Admins*))"

# Perform search and list the "Member" property of Domain Admins
$Members = $Searcher.FindAll() | % { $_.GetDirectoryEntry() } | Select-Object -ExpandProperty Member

# Craft our XPATH query, including each member of Domain Admins
$Query = "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634 or EventID=4625 or EventID=4648 or EventID=4740)]]*[EventData[Data[@Name='TargetUserName'] and ("

for ($i=0; $i -lt $Members.Count; $i++) {
	# Use Regular Expression to filter the name out of the full LDAP object path
	if ($Members[$i] -match "(^CN=)([a-z0-9]+)(,.*)") {
		[String]$MemberName = $matches[2]
		$Query = $Query + "Data='" + $MemberName + "'"
	}
	
	if ($i -ne ($Members.Count-1)) {
		$Query = $Query + " or "
	}
}

$Query = $Query + ")]]</Select></Query></QueryList>"

Set-WECSubscription -Name "Domain Admin Account Monitoring" -Query $Query