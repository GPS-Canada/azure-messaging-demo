using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Azure.Relay;

var client = new SecretClient(vaultUri: new Uri("https://ev-demo1-kv.vault.azure.net/"), credential: new DefaultAzureCredential());
var relayConnectionString = client.GetSecret("Relay--Listen-ConnectionString").Value.Value;

Console.Write("Enter the Relay path you want to listen to (i.e. campus1): ");
var relayPath = Console.ReadLine();
if (string.IsNullOrEmpty(relayPath)) relayPath = "ev-demo1-topic-relay2";

var hybridConnectionlistener1 = new HybridConnectionListener(
    connectionString: relayConnectionString, //"Endpoint=sb://av-relay.servicebus.windows.net/;SharedAccessKeyName=CampusListeners;SharedAccessKey=0ys4uJ+/LaFZc7ho5ItrLYF7AIAFLtWVRD4vJNnwsrk=",
    path: relayPath); //"campus3"

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
