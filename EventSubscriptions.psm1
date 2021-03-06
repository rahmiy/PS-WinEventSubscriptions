function Get-WECSubscription {
<#
.SYNOPSIS
	Returns a list of Subscriptions in the Windows Event Collector.
	
.DESCRIPTION
	Uses wecutil.exe to interact with the Windows Event Collector and return information about subscriptions currently available on the system.

.PARAMETER Name
	Optional parameter if you want to list information about a specific subscription.

.EXAMPLE
	Get-WECSubscription

.EXAMPLE
	Get-WECSubscription -Name "Test Subscription"
#>
[CmdletBinding()]Param (
	[Parameter(Mandatory=$False)][String]$Name
)

# Create an empty array to store formatted scription information
$SubscriptionArray = @()

function Parse-SubscriptionInfo ($SubName) {
	$SubscriptionInfo = $null
	[XML]$SubscriptionInfo = wecutil.exe get-subscription $SubName /format:xml
	$CustomObject = New-Object PSObject
	$CustomObject | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $SubscriptionInfo.Subscription.SubscriptionID
	$CustomObject | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $SubscriptionInfo.Subscription.Enabled
	$CustomObject | Add-Member -MemberType NoteProperty -Name "Description" -Value $SubscriptionInfo.Subscription.Description
	$CustomObject | Add-Member -MemberType NoteProperty -Name "DestinationLog" -Value $SubscriptionInfo.Subscription.LogFile
	$CustomObject | Add-Member -MemberType NoteProperty -Name "SubscriptionType" -Value $SubscriptionInfo.Subscription.SubscriptionType

	# Parse the Event Sources
	$EventSourcesArray = @()
	if ($SubscriptionInfo.Subscription.EventSources) {
		ForEach ($Entry in $SubscriptionInfo.Subscription.EventSources) {
			$EventSourceObject = New-Object PSObject
			$EventSourceObject | Add-Member -MemberType NoteProperty -Name "Address" -Value $Entry.EventSource.Address
			$EventSourceObject | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $Entry.EventSource.Enabled
			$EventSourcesArray += $EventSourceObject
		}
	}
	if ($SubscriptionInfo.Subscription.AllowedSourceDomainComputers) {
		$Sources = Invoke-WmiMethod -Class Win32_SecurityDescriptorHelper -Name "SDDLToWin32SD" -ArgumentList $SubscriptionInfo.Subscription.AllowedSourceDomainComputers
		ForEach ($Entry in $Sources.Descriptor.DACL) {
			$EventSourceObject = New-Object PSObject
			$EventSourceObject | Add-Member -MemberType NoteProperty -Name "Domain" -Value $Entry.Trustee.Domain
			$EventSourceObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $Entry.Trustee.Name
			$EventSourceObject | Add-Member -MemberType NoteProperty -Name "SID" -Value $Entry.Trustee.SIDString
			$EventSourcesArray += $EventSourceObject
		}
	}
	
	$CustomObject | Add-Member -MemberType NoteProperty -Name "EventSources" -Value $EventSourcesArray

	$CustomObject | Add-Member -MemberType NoteProperty -Name "Query" -Value $SubscriptionInfo.Subscription.Query.'#cdata-section'
	$CustomObject | Add-Member -MemberType NoteProperty -Name "TransportName" -Value $SubscriptionInfo.Subscription.TransportName
	$CustomObject | Add-Member -MemberType NoteProperty -Name "TransportPort" -Value $SubscriptionInfo.Subscription.TransportPort
	$CustomObject | Add-Member -MemberType NoteProperty -Name "DeliveryOptimizaiton" -Value $SubscriptionInfo.Subscription.ConfigurationMode
	$CustomObject | Add-Member -MemberType NoteProperty -Name "CredentialsType" -Value $SubscriptionInfo.Subscription.CredentialsType

	return $CustomObject
}

if ($Name) {
	$SubscriptionArray += Parse-SubscriptionInfo $Name
} else {
	wecutil.exe enum-subscription | ForEach-Object {
		$SubscriptionArray += Parse-SubscriptionInfo $_
	}

}

$SubscriptionArray

}

function Set-WECSubscription {
<#
.SYNOPSIS
	Modifies a Subscription in the Windows Event Collector.
	
.DESCRIPTION
	Uses wecutil.exe to interact with the Windows Event Collector and modify information about subscriptions currently available on the system.

.PARAMETER Name
	Name of the subscription to be modified

.PARAMETER Enabled
	Optional parameter to set the status of the subscription.

.PARAMETER Description
	Optional parameter to set the Description of the subscription.

.PARAMETER Query
	Optional parameter to set the XPATH query of the subscription.

.PARAMETER AddSource
	Optional parameter to add a new source computer/computer group.

.PARAMETER RemoveSource
	Optional parameter to remove a source computer/computer group.

.EXAMPLE
	Set-WECSubscription -Name "Test Subscription" -Enabled "True" -Description "This is a test." -AddSource "COMPUTER001"

#>
[CmdletBinding()]Param (
	[Parameter(Mandatory=$True)][String]$Name,
	[Parameter(Mandatory=$False)][ValidateSet("True","False")][String]$Enabled,
	[Parameter(Mandatory=$False)][String]$Description,
	[Parameter(Mandatory=$False)][String]$Query,
	[Parameter(Mandatory=$False)][String[]]$AddSource,
	[Parameter(Mandatory=$False)][String[]]$RemoveSource,
	[Parameter(Mandatory=$False)][ValidateRange(1,65535)][Int]$TransportPort
)

if ($Enabled) {
	wecutil.exe set-subscription $Name /e:$Enabled
}

if ($Description) {
	wecutil.exe set-subscription $Name /d:$Description
}

if ($Query) {
	wecutil.exe set-subscription $Name /q:$Query
}

if ($AddSource) {
	ForEach ($Source in $AddSource) {
		wecutil.exe set-subscription $Name /esa:$Source
	}
}

if ($RemoveSource) {
	ForEach ($Source in $RemoveSource) {
		wecutil.exe set-subscription $Name /esa:$Source
	}
}

}
