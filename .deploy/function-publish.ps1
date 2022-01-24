Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix # Prefix used for creating applications
)

$resourceGroup = $AppNamePrefix
$functionAppName = "$AppNamePrefix-func" 
$mode = "release"

dotnet publish ..\AzureFunctionPublisher\AzureFunctionPublisher.csproj `
    --configuration $mode `
    --output "..\AzureFunctionPublisher\Publish\$mode"

Compress-Archive -Path "..\AzureFunctionPublisher\Publish\$mode\*" -DestinationPath "..\AzureFunctionPublisher\Publish\$mode.zip" -Force

az functionapp deployment source config-zip `
    --resource-group $resourceGroup `
    --name $functionAppName `
    --src "..\AzureFunctionPublisher\Publish\$mode.zip"
