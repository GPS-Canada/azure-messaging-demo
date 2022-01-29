Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
   [string][Parameter(Mandatory)]$productName, # Name of the product to deploy resources for
   [string][Parameter()]$Location = "canadaCentral", # Location of all resources
   [string][Parameter()]$subscriptionId # Id of Subscription to deploy to. If empty, defaults to the current account. Check 'az account show' to check.
)

./eventgrid -AppNamePrefix $AppNamePrefix -domainName $productName -Location $Location -subscriptionId $subscriptionId
./servicebus -AppNamePrefix $AppNamePrefix -topicName $productName -Location $Location -subscriptionId $subscriptionId 

./function -AppNamePrefix $AppNamePrefix -topicName $productName -Location $Location -subscriptionId $subscriptionId
./function-publish -appNamePrefix $AppNamePrefix

./eventgrid-newsub -appNamePrefix $AppNamePrefix -domainName $productName -topicName "$productName-1" -useRelay
./eventgrid-newsub -appNamePrefix $AppNamePrefix -domainName $productName -topicName "$productName-2" -webhookUrl "https://webhook.site/fc9f4c05-ee4a-46af-8a81-fe2698329a0e" --appendSubscriptionToWebhook


./servicebus-newsub.ps1 -AppNamePrefix $AppNamePrefix -topicName $productName -subscriptionName "$productName-1"
./servicebus-newsub.ps1 -AppNamePrefix $AppNamePrefix -topicName $productName -subscriptionName "$productName-2"