Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
   [string][Parameter()]$Location = "canadaCentral", # Location of all resources
   [string][Parameter()]$subscriptionId # Id of Subscription to deploy to. If empty, defaults to the current account. Check 'az account show' to check.
)


./eventgrid -AppNamePrefix $AppNamePrefix -Location $Location -subscriptionId $subscriptionId
./function -AppNamePrefix $AppNamePrefix -Location $Location -subscriptionId $subscriptionId
./function-publish -appNamePrefix $AppNamePrefix

./eventgrid-newsub -appNamePrefix $AppNamePrefix -topicName "relay1" -relayName "$AppNamePrefix-relay"
./eventgrid-newsub -appNamePrefix $AppNamePrefix -topicName "webhook1" -webhookUrl "https://webhook.site/fc9f4c05-ee4a-46af-8a81-fe2698329a0e" --appendSubscriptionToWebhook