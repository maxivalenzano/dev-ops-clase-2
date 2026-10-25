using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace Backend.Tests;

public class DatabaseContractTests : IClassFixture<TestApplicationFactory>
{
    private readonly HttpClient client;
    public DatabaseContractTests(TestApplicationFactory factory) => client = factory.CreateClient();

    [Theory]
    [InlineData(0)]
    [InlineData(9)]
    public async Task CreateRejectsOutOfRangePriority(int priority)
    {
        var result = await client.PostAsJsonAsync("/api/tasks", new { title = "Invalid", priority });
        Assert.Equal(HttpStatusCode.BadRequest, result.StatusCode);
    }

    [Fact]
    public async Task ReadinessReturnsExplicitStorage()
    {
        var result = await client.GetAsync("/api/ready");
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Contains("TestMemory", await result.Content.ReadAsStringAsync());
    }
}
