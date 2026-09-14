using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Backend.Tests;

public class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task HealthEndpoint_LifecycleAndToggle_ReturnsExpectedStatusCodesAndPayloads()
    {
        // Arrange
        var client = _factory.CreateClient();

        // 1. Estado inicial (UP / 200 OK)
        var initialResponse = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, initialResponse.StatusCode);

        var initialContent = await initialResponse.Content.ReadAsStringAsync();
        using var initialDoc = JsonDocument.Parse(initialContent);
        Assert.Equal("UP", initialDoc.RootElement.GetProperty("status").GetString());

        // 2. Toggle a DOWN (/api/health/toggle)
        var toggleToDown = await client.PostAsync("/api/health/toggle", null);
        Assert.Equal(HttpStatusCode.OK, toggleToDown.StatusCode);

        // 3. Verificar que /health responde 500 InternalServerError y status DOWN
        var downResponse = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.InternalServerError, downResponse.StatusCode);

        var downContent = await downResponse.Content.ReadAsStringAsync();
        using var downDoc = JsonDocument.Parse(downContent);
        Assert.Equal("DOWN", downDoc.RootElement.GetProperty("status").GetString());
        Assert.True(downDoc.RootElement.TryGetProperty("error", out _));

        // 4. Toggle de retorno a UP
        var toggleToUp = await client.PostAsync("/api/health/toggle", null);
        Assert.Equal(HttpStatusCode.OK, toggleToUp.StatusCode);

        // 5. Verificar recuperación (UP / 200 OK)
        var restoredResponse = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, restoredResponse.StatusCode);

        var restoredContent = await restoredResponse.Content.ReadAsStringAsync();
        using var restoredDoc = JsonDocument.Parse(restoredContent);
        Assert.Equal("UP", restoredDoc.RootElement.GetProperty("status").GetString());
    }

    [Fact]
    public async Task RootEndpoint_ReturnsOnlineStatus()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.Equal("Backend service is online", doc.RootElement.GetProperty("message").GetString());
    }

    [Fact]
    public async Task InfoEndpoint_ReturnsSystemMetricsAndInstanceInfo()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/info");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;

        Assert.True(root.TryGetProperty("instance", out _));
        Assert.True(root.TryGetProperty("memory", out var mem));
        Assert.True(mem.TryGetProperty("rssMB", out _));
    }
}
