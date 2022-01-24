using Azure.Messaging.ServiceBus;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var keyVaultUrl = "https://ev-demo1-kv.vault.azure.net/";
var secretName = "ServiceBus--Listen-ConnectionString";
var serviceBusPath = "ev-demo1-topic-sb1";

var kvClient = new SecretClient(vaultUri: new Uri(keyVaultUrl), credential: new DefaultAzureCredential());
var sbConnectionString = kvClient.GetSecret(secretName).Value.Value;

// Console.Write("Enter the ServiceBus queue/topic name you want to listen to (i.e. ev-demo1-topic-sb1): ");
// var serviceBusPath = Console.ReadLine();
// if (string.IsNullOrEmpty(serviceBusPath)) serviceBusPath = "ev-demo1-topic-sb1";

await using var client = new ServiceBusClient(sbConnectionString);
var processor = client.CreateProcessor(serviceBusPath, new ServiceBusProcessorOptions());

processor.ProcessMessageAsync += (args) =>
{
    Console.WriteLine(args.Message.Body.ToString());

    return Task.CompletedTask; 
};
processor.ProcessErrorAsync += (args) =>
{
    Console.WriteLine(args.Exception.Message.ToString());
    return Task.CompletedTask;
};

await processor.StartProcessingAsync();
Console.WriteLine("Waiting for messages....");

Console.ReadKey();

await processor.StopProcessingAsync();
Console.WriteLine("Done");
