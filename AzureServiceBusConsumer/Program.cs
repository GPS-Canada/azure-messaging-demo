// See https://aka.ms/new-console-template for more information
using Azure.Messaging.ServiceBus;

await using var client = new ServiceBusClient("Endpoint=sb://av-servicebus1.servicebus.windows.net/;SharedAccessKeyName=OnPremListener;SharedAccessKey=+d467vWlpTfxuNmqUbL+0u5KW4X/pg4n0cEVpH/gBVI=");

var processor = client.CreateProcessor("campus4", new ServiceBusProcessorOptions());

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
