using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using Backend.Models;
using Backend.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace Backend.Tests;

public class DatabaseDeadlineTests
{
    [Theory]
    [InlineData("GET")]
    [InlineData("POST")]
    public async Task DatabaseDeadlineCancelsServiceAndReturns503BeforeGatewayTimeout(string method)
    {
        await using var factory = new SlowDatabaseFactory();
        var client = factory.CreateClient();
        var elapsed = Stopwatch.StartNew();
        var response = method == "GET"
            ? await client.GetAsync("/api/tasks")
            : await client.PostAsJsonAsync("/api/tasks", new { title = "Deadline test" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Contains("Database request timed out", await response.Content.ReadAsStringAsync());
        Assert.True(factory.Service.CancellationObserved);
        Assert.True(elapsed.Elapsed < TimeSpan.FromSeconds(4.5), $"Database deadline took {elapsed.Elapsed}");
    }

    [Fact]
    public async Task ChaosDelayKeepsItsSeparateTimingBehavior()
    {
        await using var factory = new TestApplicationFactory();
        var response = await factory.CreateClient().GetAsync("/api/delay?ms=2100");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private sealed class SlowDatabaseFactory : TestApplicationFactory
    {
        public SlowTaskService Service { get; } = new();
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<ITaskService>();
                services.AddSingleton<ITaskService>(Service);
            });
        }
    }

    private sealed class SlowTaskService : ITaskService
    {
        public bool CancellationObserved { get; private set; }
        private async Task WaitForCancellation(CancellationToken cancellationToken)
        {
            try { await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken); }
            finally { CancellationObserved = cancellationToken.IsCancellationRequested; }
        }
        public async Task<IEnumerable<TaskItem>> GetAllTasksAsync(CancellationToken cancellationToken = default)
        {
            await WaitForCancellation(cancellationToken);
            return [];
        }
        public async Task<TaskItem> CreateTaskAsync(string title, string nodeName, int priority = 2, CancellationToken cancellationToken = default)
        {
            await WaitForCancellation(cancellationToken);
            return new TaskItem(title, nodeName);
        }
        public Task<TaskItem?> GetTaskByIdAsync(string id, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<TaskItem?> ToggleTaskAsync(string id, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<bool> DeleteTaskAsync(string id, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
