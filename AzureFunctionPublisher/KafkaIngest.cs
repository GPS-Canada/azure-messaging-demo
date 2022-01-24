using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Collections.Generic;
using Azure.Messaging.EventGrid;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using System.Linq;

namespace AzureFunctionPublisher
{
    public static class KafkaIngest
    {
        [FunctionName("ToEventGrid")]
        public static async Task<IActionResult> ToEventGrid(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
            [EventGrid(TopicEndpointUri = "EventGrid--Domain-Url", TopicKeySetting = "EventGrid--Domain-Key")] IAsyncCollector<EventGridEvent> outputEvent,
            ILogger log)
        {
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var data = JsonConvert.DeserializeObject<List<EventDTO>>(requestBody);
            var topicPrefix = Environment.GetEnvironmentVariable("TopicPrefix", EnvironmentVariableTarget.Process);

            var key = Environment.GetEnvironmentVariable("EventGrid-Domain-Key", EnvironmentVariableTarget.Process);
            log.LogDebug(key);

            foreach (var item in data)
            {
                var newEvent = new EventGridEvent("subject", "event-type", "v1.0", item)
                {
                    Topic = $"{topicPrefix}-{item.DestinationId.ToLower()}",
                };

                await outputEvent.AddAsync(newEvent);
            }

            return new OkObjectResult(data.First().DestinationId);
        }


        public class EventDTO
        {
            public string DestinationId { get; set; }

            public string Data { get; set; }
        }
    }
}

