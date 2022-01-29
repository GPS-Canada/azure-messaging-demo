Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
   [string][Parameter()]$subscriptionId ,
   [string][Parameter()]$topicName, #Topic name to create subscription for.
   [string][Parameter()]$subscriptionName, #Name of subscription
   [int][Parameter()]$defaultTimeToLiveInDays = 4 #Name of subscription

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
$serviceBusName = ($AppNamePrefix + "servicebus") -replace "[^a-z0-9]",""

Write-Host "Creating Service Bus Subscription '$subscriptionName'"
az servicebus topic subscription create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--topic-name $topicName `
	--name $subscriptionName `
	--max-delivery-count 2 `
	--default-message-time-to-live "P$($defaultTimeToLiveInDays)D" `
	--output none

Write-Host "Service Bus Subscription '$subscriptionName' created"

Write-Host "Creating Service Bus Subscription Filter"

# This does not work due to a bug in the CLI -> Cannot create CorrelationFilter rule -> https://github.com/Azure/azure-cli/issues/12369
#az servicebus topic subscription rule create `
#	--resource-group $resourceGroup `
#	--namespace-name $serviceBusName `
#	--topic-name $topicName `
#	--subscription-name $subscriptionName `
#	--name "filter-on-label"
#	--label $subscriptionName

#using workaround as found here -> https://stackoverflow.com/questions/56031534/creating-topic-filter-rule-via-correlationfilter-with-azure-functions-app/56116477#56116477

$rule = New-AzServiceBusRule -ResourceGroupName $resourceGroup -Namespace $serviceBusName -Topic $topicName -Subscription $subscriptionName -Name "rule1" -SqlExpression "1=1"
$rule.FilterType = 1 # 1=correlationfilter 0=SQLFilter
$rule.SqlFilter = $null
$rule.CorrelationFilter.Label = $subscriptionName
Set-AzServiceBusRule -ResourceGroupName $resourceGroup -Namespace $serviceBusName -Topic $topicName -Subscription $subscriptionName -Name "rule1" -InputObject $rule


Write-Host "Creating Service Bus Subscription Filter Created"
