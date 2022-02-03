### Intro

This is a proof of concept for creating a messaging solution between Azure and On-Prem clients.

There are 3 components to this demo
1. An Azure Function that publishes to either a Service Bus Topic or Event Grid Domain
2. Event Grid Domain implementation either to push to a webhook (public) or privately though an Azure Relay.
3. Service Bus implementation

## Prerequisites
- [Azure Functions Core tools 4.x](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local) -- [Download](https://go.microsoft.com/fwlink/?linkid=2174087)

- [Azure ClI 2.32+](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)


## Deployment

All the components from this solution can be deployed via PowerShell az CLI scripts

Shared components (Storage Account, Resource group, Key Vault, etc...) can be deployed by either script so it does not matter which one you run

1. [eventgrid.ps1](https://github.com/GPS-Canada/azure-messaging-demo/blob/main/.deploy/eventgrid.ps1) - will deploy an Event Grid Domain and Azure Relay 
2. [servicebus.ps1](https://github.com/GPS-Canada/azure-messaging-demo/blob/main/.deploy/servicebus.ps1) - will deploy Service Bus components
3. [function.ps1](https://github.com/GPS-Canada/azure-messaging-demo/blob/main/.deploy/function.ps1) - will deploy the Azure Function that is used for test publishing messages
4. [function-publish.ps1](https://github.com/GPS-Canada/azure-messaging-demo/blob/main/.deploy/function-publish.ps1) - will publish the Azure Function applicaiton in the newly deployed Function App
5. eventgrid-newsub and servicebus-newsub will create subscriptions that allow clients to recieve messages. You can have more than one subscription for each. **Note: If you are using a webhook subscription for event grid, a verification message will be sent to the URL and that needs to be called before the subscription is enabled.
6. [deploy-all.ps1](https://github.com/GPS-Canada/azure-messaging-demo/blob/main/.deploy/deploy-all.ps1) - will deploy the entire infrastructure in one go.

## Usage

Once everything is deployed, run the AzureRelayConsumer and Azure ServiceBusConsumer projects locally. You will likely need to update the KeyVault Url to match the instance you deployed but everything else should flow from there.

Once running, you can Post to the Azure Function you deployed to send a message though either Event Grid (using the ToEventGrid function) or Service Bus (using the ToServiceBus function). The body of the post needs to contain a "destinationId" property that matches the name of your subscription you created when you deployed the infrastructure.

This project demonstrates the routing abilities of either Evet Grid - by pushing the message to a specific Topic/Subscription of the Event Grid Domain based on the destinationId property, or Service Bus Subscription Filters - by using a correlation filter on the message that gets processed.


