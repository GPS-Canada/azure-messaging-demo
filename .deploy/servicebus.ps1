#This script will deploy the basic infrastructure for the appliation
# - Verify EventGrid is registered on the required subscription
# - Creates a resource group
# - Creates a KeyVault
# - Creates an Azure Storage Account and save the connection string in the KeyVault
# - Creates an Azure Relay Namespace along with a Listener and Sender Shared Access Policy that are saved in the KeyVault
# - Creates an Event Grid Domain and a global subscription for the domain into a storage queue (for monitoring events)

Param(  
	[string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
	[string][Parameter(Mandatory)]$topicName, # Topic to be created
	[string][Parameter()]$location = "canadaCentral", # Location of all resources
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
$serviceBusName = ($AppNamePrefix + "servicebus") -replace "[^a-z0-9]",""

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

#setting up Service Bus
$serviceBusExists = !(az servicebus namespace exists --name $serviceBusName --query "{n:nameAvailable}" --output tsv)
if ($serviceBusExists -eq $false) {
	Write-Host "Service Bus namespace '$serviceBusName' does not exist. Creating..."

	az servicebus namespace create `
		--resource-group $resourceGroup `
		--location $location `
		--name $serviceBusName `
		--sku Standard `
		--output none
	Write-Host "Service Bus namespace '$serviceBusName' created."
}
else {
	Write-Host "Service Bus namespace '$serviceBusName' exists. Skipping..."
}

#Setting up Service Bus Topic
az servicebus topic create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--name $topicName `
	--output none

Write-Host "Service Bus Topic '$topicName' created"

az servicebus topic authorization-rule create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--topic-name $topicName `
	--name "$topicName-listener" `
	--rights "Listen" `
	--output none

az servicebus topic authorization-rule create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--topic-name $topicName `
	--name "$topicName-sender" `
	--rights "Send" `
	--output none

$listenerConnectionString = `
	az servicebus topic authorization-rule keys list `
		--resource-group $resourceGroup `
		--namespace-name $serviceBusName `
		--topic-name $topicName `
		--name "$topicName-listener" `
		--query "{cs:primaryConnectionString}" `
		--output tsv

$senderConnectionString = `
	az servicebus topic authorization-rule keys list `
		--resource-group $resourceGroup `
		--namespace-name $serviceBusName `
		--topic-name $topicName `
		--name "$topicName-sender" `
		--query "{cs:primaryConnectionString}" `
		--output tsv

az keyvault secret set `
	--vault-name $keyVaultName `
	--name "ServiceBus--$topicName-Listen-ConnectionString" `
	--value $listenerConnectionString `
	--output none

az keyvault secret set `
	--vault-name $keyVaultName `
	--name "ServiceBus--$topicName-Send-ConnectionString" `
	--value $senderConnectionString `
	--output none

Write-Output "Service Bus topic Endpoint and Key added in KeyVault"