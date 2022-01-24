#This script will deploy the basic infrastructure for the appliation
# - Verify EventGrid is registered on the required subscription
# - Creates a resource group
# - Creates a KeyVault
# - Creates an Azure Storage Account and save the connection string in the KeyVault
# - Creates an Azure Relay Namespace along with a Listener and Sender Shared Access Policy that are saved in the KeyVault
# - Creates an Event Grid Domain and a global subscription for the domain into a storage queue (for monitoring events)

Param(  
	[string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
	[string][Parameter()]$Location = "canadaCentral", # Location of all resources
	[string][Parameter()]$subscriptionId # Id of Subscription to deploy to. If empty, defaults to the current account. Check 'az account show' to check.
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
$keyVaultName = "$AppNamePrefix-kv"
$storageQueueName = "eventgridsink"
$storageContainerName = "eventgriddeadletter"
$relayName = "$AppNamePrefix-relay"
$domainName = "$AppNamePrefix-domain"
$subscriptionGlobal = "sub-global"
$domainResourceId ="/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.EventGrid/domains/$domainName"
$eventSinkResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageName/queueservices/default/queues/$storageQueueName"


##Event Grid Registration
$registrationStatus = az provider show --namespace Microsoft.EventGrid --query "registrationState"
if ($registrationStatus -ne '"Registered"'){
	Write-Output "Event Grid was not registered. Registering..."
	az provider register --namespace Microsoft.EventGrid
	Write-Output "Microsoft.EventGrid registered"
}

###Resource Group creation
$rgExists = az group exists --name $resourceGroup 
if ($rgExists -eq 'false'){

	Write-Output "Resource Group '$resourceGroup' does not exist. Creating..."
	az group create `
		--name $resourceGroup `
		--location $location `
		--output none
	Write-Output "Resource Group '$resourceGroup' created"
}
else {
	Write-Output "Resource Group '$resourceGroup' already exists. Skipping..."
}

###Setting up Key Vault
$kvExists = az keyvault list --query "[?name=='$keyVaultName']" --output tsv
if ($null -eq $kvExists){
	Write-Host "KeyVault '$keyVaultName' does not exist. Creating..."
	az keyvault create `
		--resource-group $resourceGroup `
		--location $location `
		--name $keyVaultName `
		--output none
	Write-Output "Resource Group '$resourceGroup' created"
}
else {
	Write-Host "KeyVault '$keyVaultName' exists. Skipping..."
}


###Setting up Storage account and Queue
$storageAvailable = az storage account check-name --name $storagename --query "nameAvailable"
if ($storageAvailable -eq $true){
	Write-Output "Storage Account '$storagename' does not exist. Creating..."
	az storage account create `
		--resource-group $resourceGroup `
		--location $location `
		--name $storagename `
		--sku Standard_LRS `
		--output none
	Write-Output "Storage Account '$storagename' created"

	$storageConnectionString = az storage account show-connection-string `
		--resource-group $resourceGroup `
		--name $storagename `
		--output tsv
	
	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'Storage--ConnectionString' `
		--value $storageConnectionString `
		--output none
}
else {
	Write-Output "Storage Account '$storagename' already exists. Skipping..."
}

$storageConnectionString = az storage account show-connection-string `
	--resource-group $resourceGroup `
	--name $storagename `
	--output tsv

Write-Output "Creating storage queue '$storageQueueName'..."
az storage queue create `
	--name $storageQueueName `
	--connection-string $storageConnectionString `
	--output none
Write-Output "Storage queue '$storageQueueName' created"

Write-Output "Creating storage deadletter container '$storageContainerName'..."
az storage container create `
	--name $storageContainerName `
	--connection-string $storageConnectionString `
	--output none
Write-Output "Storage deadletter container '$storageContainerName' created"

#Setting up Azure Relay
$relayExists = az relay namespace list --query "[?name=='$relayName']" --output tsv
if ($null -eq $relayExists){
	Write-Output "Relay '$relayName' does not exist. Creating..."
	az relay namespace create `
		--resource-group $resourceGroup `
		--name $relayName `
		--location $location `
		--output none
	Write-Output "Relay '$relayName' created"

	Write-Output "Creating publishing AccessKey for '$relayName'"
	az relay namespace authorization-rule create `
		--resource-group $resourceGroup `
		--namespace-name $relayName `
		--rights "Send" `
		--name "FunctionSend" `
		--output none

	$relaySendConnectionString = az relay namespace authorization-rule keys list `
		--resource-group $resourceGroup `
		--namespace-name $relayName `
		--name "FunctionSend" `
		--query "{cs:primaryConnectionString}" `
		--output tsv

	Write-Output "Created publishing AccessKey for '$relayName'"

	Write-Output "Creating listener AccessKey for '$relayName'"
	az relay namespace authorization-rule create `
		--resource-group $resourceGroup `
		--namespace-name $relayName `
		--rights "Listen" `
		--name "ConsumersListen" `
		--output none

	$relayListenConnectionString = az relay namespace authorization-rule keys list `
		--resource-group $resourceGroup `
		--namespace-name $relayName `
		--name "ConsumersListen" `
		--query "{cs:primaryConnectionString}" `
		--output tsv

	Write-Output "Created listener AccessKey for '$relayName'"

	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'Relay--Send-ConnectionString' `
		--value $relaySendConnectionString `
		--output none

	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'Relay--Listen-ConnectionString' `
		--value $relayListenConnectionString `
		--output none

	Write-Output "Relay ConnectionString added in KeyVault "

}
else {
	Write-Output "Relay '$relayName' already exists. Skipping..."
}

#Setting up Event Grid Domain
$eventGridDomainExists = az eventgrid domain list --query "[?name=='$domainName'].{Name:name}" --output tsv
if ($null -eq $eventGridDomainExists){

	Write-Output "Domain '$domainName' does not exist. Creating..."
	$domainEndpoint = `
		az eventgrid domain create `
			--resource-group $resourceGroup `
			--location $location `
			--name $domainName `
			--query "{url:endpoint}" `
			--output tsv
	
	Write-Output "Domain '$domainName' created"

	$domainKey = `
		az eventgrid domain key list `
			--resource-group $resourceGroup `
			--name $domainName `
			--query "{key:key1}" `
			--output tsv
	
	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'EventGrid--Domain-Url' `
		--value $domainEndpoint `
		--output none

	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'EventGrid--Domain-Key' `
		--value $domainKey `
		--output none

	Write-Output "Domain Endpoint and Key added in KeyVault"
}
else {
	Write-Output "Domain '$domainName' already exists. Skipping..."
}

#Setting up Event Grid Subscriptions

#https://docs.microsoft.com/en-us/cli/azure/eventgrid/event-subscription?view=azure-cli-latest#az-eventgrid-event-subscription-create

az eventgrid event-subscription create `
	--name $subscriptionGlobal `
	--source-resource-id $domainResourceId `
	--endpoint-type storagequeue `
    --endpoint $eventSinkResourceId `
    --storage-queue-msg-ttl 300 `
	--output none

Write-Output "Global subscription '$subscriptionGlobal' created"