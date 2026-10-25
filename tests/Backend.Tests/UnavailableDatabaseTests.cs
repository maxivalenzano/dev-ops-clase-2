using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Backend.Tests;

public class UnavailableDatabaseTests
{
    [Fact]
    public async Task DatabaseFailureKeepsLivenessButRejectsReadsAndWrites()
    {
        await using var factory = new OfflineDatabaseFactory();
        var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/health")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/api/ready")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/api/tasks")).StatusCode);
        var write = await client.PostAsJsonAsync("/api/tasks", new { title = "Must never exist locally" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, write.StatusCode);
        Assert.DoesNotContain("Password", await write.Content.ReadAsStringAsync());
    }

    private sealed class OfflineDatabaseFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Postgres"] = "Host=127.0.0.1;Port=1;Database=offline;Username=offline;Pooling=false"
            }));
        }
    }
}
