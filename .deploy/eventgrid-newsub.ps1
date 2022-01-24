Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
   [string][Parameter()]$topicName, #Topic name to create subscription for. If empty, subscription will be created for the entire domain   

   [string][Parameter()]$relayName, #Relay for subscription. If empty, must provide public webhool url
   [string][Parameter()]$webhookUrl, #Public webhook url for subscription. If empty, must provide relay name
   [switch][Parameter()]$appendSubscriptionToWebhook, # Subscription Id to be appended to the webhook url
   [string][Parameter()]$subscriptionId 
)

### Subscription Selection
if ($subscriptionId -ne ""){
	az account set -s $subscriptionId
}
else {
	$subscriptionId = az account show --query "id" --output tsv
}

#Variable setup
$resourceGroup = $AppNamePrefix
$storageName = ($AppNamePrefix + "storage") -replace "[^a-z0-9]",""

$storageContainerName = "eventgriddeadletter"
$domainName = "$AppNamePrefix-domain"
$topicName = "$AppNamePrefix-$topicName"
$subscriptionName = "$topicName-sub1"

$subscriptionResourceId = 
	if ($topicName -eq "") {
		$"/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.EventGrid/domains/$domainName"} 
	else {	
		"/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.EventGrid/domains/$domainName/topics/$topicName"
	}
$deadletterResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageName/blobServices/default/containers/$storageContainerName"



if ($webhookUrl -ne ""){

	Write-Host "Creating webhook subscription"
	
	if($appendSubsriptionToWebhook) { $webhookUrl= "$webhookUrl/$subscriptionName"}

	az eventgrid event-subscription create `
		--name $subscriptionName `
		--source-resource-id $subscriptionResourceId `
		--endpoint $webhookUrl `
		--endpoint-type WebHook `
		--deadletter-endpoint $deadletterResourceId `
		--max-delivery-attempts 2 --event-ttl 120 `
		--output none

	Write-Host "Webhook subscription created"

}
elseif ($relayName -ne ""){

	Write-Output "Creating Event Grid Relay Subscription"
	if ($topicName -eq "") {$topicName = "global"}

	$relayEndpointId = az relay hyco create `
			--resource-group $resourceGroup `
			--namespace-name $relayName `
			--name $topicName `
			--requires-client-authorization false `
			--query "{id:id}" `
			--output tsv

	az eventgrid event-subscription create `
		--name $subscriptionName `
		--source-resource-id $subscriptionResourceId `
		--endpoint $relayEndpointId `
		--endpoint-type hybridconnection `
		--deadletter-endpoint $deadletterResourceId `
		--max-delivery-attempts 2 --event-ttl 120 `
		--output none

	Write-Output "Event Grid Relay Subscription Created."
}
else {
	Write-Warning "No subscription created. Please provide either a webhook url or a relay name"
}