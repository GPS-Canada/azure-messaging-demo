using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Azure.Relay;

var keyVaultUrl = "https://demo-pubsub-1-kv.vault.azure.net/";
var secretName = "Relay--Listen-ConnectionString";
var relayPath = "campus-1";


var client = new SecretClient(vaultUri: new Uri(keyVaultUrl), credential: new DefaultAzureCredential());
var relayConnectionString = client.GetSecret(secretName).Value.Value;

// Console.Write("Enter the Relay path you want to listen to (i.e. ev-demo1-topic-relay1): ");
// var relayPath = Console.ReadLine();
// if (string.IsNullOrEmpty(relayPath)) relayPath = "ev-demo1-topic-relay2";

var hybridConnectionlistener1 = new HybridConnectionListener(
    connectionString: relayConnectionString,
    path: relayPath); 

hybridConnectionlistener1.RequestHandler = (context) =>
{
    var content = new StreamReader(context.Request.InputStream).ReadToEnd();

    Console.ForegroundColor = ConsoleColor.DarkGreen;
    Console.WriteLine($"1: {content}");
    Console.ForegroundColor = ConsoleColor.White;

    context.Response.StatusCode = System.Net.HttpStatusCode.OK;
    context.Response.Close();
};


await hybridConnectionlistener1.OpenAsync();

Console.WriteLine("Waiting for messages....");

Console.ReadKey();

Console.WriteLine("Done");
