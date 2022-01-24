Param(  
   [string][Parameter(Mandatory)]$appNamePrefix, # Prefix used for creating applications
   [string][Parameter()]$location = "canadaCentral", # Prefix used for creating applications
   [string][Parameter()]$subscriptionId, # Prefix used for creating applications
   [switch][Parameter()]$usePremiumPlan # Prefix used for creating applications
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
# $functionPlanName = "$AppNamePrefix-asp"
# $functionPlanSKU = if($usePremiumPlan -eq $true) { "EP1" } else { "Y1" }
$functionAppName = "$AppNamePrefix-func" 
$keyVaultName = "$AppNamePrefix-kv"
$functionWorkspace = "$AppNamePrefix-workspace"
$functionInsights = "$AppNamePrefix-ai"


##Resource Group creation
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


#create keyvault
$kvExists = az keyvault list --query "[?name=='$keyVaultName'].{Name:name}" --output tsv
if ($null -eq $kvExists){
	Write-Host "KeyVault '$keyVaultName' does not exist. Creating..."
	az keyvault create `
		--resource-group $resourceGroup `
		--location $location `
		--name $keyVaultName `
		--output none
	Write-Output "KeyVault '$keyVaultName' created"
}
else {
	Write-Host "KeyVault '$keyVaultName' exists. Skipping..."
}

###Setting up Storage Account
$storageAvailable = az storage account check-name --name $storagename --query "nameAvailable"
if ($storageAvailable -eq $true){
	Write-Output "Storage Account '$storagename' does not exist. Creating..."
	az storage account create `
		--resource-group $resourceGroup `
		--location $location `
		--name $storagename `
		--sku Standard_LRS `
		--output tsv
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

##Application Insights
Write-Host "Creating App Insights '$appInsightsName'..."	

az monitor log-analytics workspace create `
	--resource-group $resourceGroup `
	--workspace-name $functionWorkspace `
	--output none

$appInsightsKey = az monitor app-insights component create `
		--resource-group $resourceGroup `
		--app $functionInsights `
		--location $location `
		--workspace $functionWorkspace `
		--kind web `
		--application-type web `
		--query "{ik:instrumentationKey}" `
		--output tsv

Write-Output "App Insights '$appInsightsName' created"

#Creating function

Write-Host "Creating Azure Functions '$functionAppName'"	

# Write-Host "-> Creating App Service Plan with '$functionPlanSKU' SKU"
# az functionapp plan create `
#   --resource-group $resourceGroup `
#   --location $location `
#   --name $functionPlanName `
#   --sku $functionPlanSKU `
#   --output none

$functionExist = az functionapp list --query "[?name=='$functionAppName']" --output tsv
if($null -eq $functionExist){
	#--plan $functionPlanName `
	Write-Host "-> Creating Azure Functions '$functionAppName'"	
	az functionapp create `
		--resource-group $resourceGroup `
		--name $functionAppName `
		--consumption-plan-location $location `
		--storage-account $storageName `
		--assign-identity `
		--functions-version 4 `
		--os-type Windows `
		--runtime dotnet `
		--app-insights $functionInsights `
		--app-insights-key $appInsightsKey `
		--output none

	$functionIdentity = 
		az webapp identity show `
			--resource-group $resourceGroup `
			--name $functionAppName `
			--query "{id:principalId}" `
			--output tsv

	az functionapp config appsettings set `
			--resource-group $resourceGroupName `
			--name $functionAppName `
			--output none `
			--settings 	TopicPrefix=$appNamePrefix `
						EventGrid-Domain-Url="@Microsoft.KeyVault(VaultName=$keyVaultName;SecretName=EventGrid--Domain-Url)" `
						EventGrid-Domain-Key="@Microsoft.KeyVault(VaultName=$keyVaultName;SecretName=EventGrid--Domain-Key)"

	Write-Host "-> Set KeyVault Access policy for function app"	
	az keyvault set-policy `
		--resource-group $resourceGroup `
		--name $keyVaultName `
		--object-id $functionIdentity `
		--secret-permissions get list `
		--output none

	Write-Host "Azure Functions '$functionAppName' created."	
}
else {
	Write-Output "Azure Functions '$functionAppName' already exists. Skipping..."
}