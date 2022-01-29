using Azure.Messaging.ServiceBus;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var keyVaultUrl = "https://demo-pubsub-1-kv.vault.azure.net/";
var serviceBusTopic = "campus";
var secretName = $"ServiceBus--{serviceBusTopic}-Listen-ConnectionString";
var serviceBusSbscription = "campus-1";

var kvClient = new SecretClient(vaultUri: new Uri(keyVaultUrl), credential: new DefaultAzureCredential());
var sbConnectionString = kvClient.GetSecret(secretName).Value.Value;

await using var client = new ServiceBusClient(sbConnectionString);
var processor = client.CreateProcessor(serviceBusTopic, serviceBusSbscription, new ServiceBusProcessorOptions());

processor.ProcessMessageAsync += (args) =>
{
    Console.WriteLine(args.Message.Body.ToString());
    
    return Task.CompletedTask; 
};
processor.ProcessErrorAsync += (args) =>
{
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.WriteLine($"   {args.Exception.Message.ToString()}");
    Console.ForegroundColor = ConsoleColor.White;
    return Task.CompletedTask;
};

await processor.StartProcessingAsync();
Console.WriteLine("Waiting for messages....");

Console.ReadKey();

await processor.StopProcessingAsync();
Console.WriteLine("Done");
