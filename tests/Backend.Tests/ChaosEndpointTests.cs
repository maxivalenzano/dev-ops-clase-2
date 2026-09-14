using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Backend.Tests;

public class ChaosEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ChaosEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task DelayEndpoint_WithCustomMs_ReturnsOkAndPayload()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act - usamos un delay muy corto (10ms) para que los tests corran de forma inmediata
        var response = await client.GetAsync("/api/delay?ms=10");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;

        Assert.Equal(10, root.GetProperty("delayMs").GetInt32());
        Assert.Contains("10ms", root.GetProperty("message").GetString());
        Assert.False(string.IsNullOrWhiteSpace(root.GetProperty("instance").GetString()));
    }

    [Fact]
    public async Task CpuStressEndpoint_WithQueryParam_ExecutesComputationAndReturnsMetrics()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act - duración muy corta (15ms) para validar la ruta sin demorar la suite
        var response = await client.PostAsync("/api/stress/cpu?duration=15", null);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;

        Assert.Equal(15, root.GetProperty("durationMs").GetInt32());
        Assert.True(root.GetProperty("operations").GetInt64() >= 0);
        Assert.Contains("CPU stress completed", root.GetProperty("message").GetString());
    }

    [Fact]
    public async Task CpuStressEndpoint_WithJsonBody_ExecutesComputation()
    {
        // Arrange
        var client = _factory.CreateClient();
        var requestBody = new CpuStressRequest(10);

        // Act
        var response = await client.PostAsJsonAsync("/api/stress/cpu", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;

        Assert.Equal(10, root.GetProperty("durationMs").GetInt32());
        Assert.True(root.GetProperty("operations").GetInt64() >= 0);
    }

    [Fact]
    public async Task MemoryStressEndpoint_AllocateAndClear_ManagesBufferStateProperly()
    {
        // Arrange
        var client = _factory.CreateClient();

        // 1. Asignar 2 MB vía Query Param
        var allocResponse1 = await client.PostAsync("/api/stress/memory?mb=2", null);
        Assert.Equal(HttpStatusCode.OK, allocResponse1.StatusCode);

        var content1 = await allocResponse1.Content.ReadAsStringAsync();
        using var doc1 = JsonDocument.Parse(content1);
        Assert.True(doc1.RootElement.GetProperty("chunksRetained").GetInt32() >= 1);
        Assert.True(doc1.RootElement.GetProperty("totalBuffersRetainedMB").GetDouble() >= 2.0);

        // 2. Asignar 2 MB adicionales vía JSON Body
        var allocResponse2 = await client.PostAsJsonAsync("/api/stress/memory", new MemoryStressRequest(2));
        Assert.Equal(HttpStatusCode.OK, allocResponse2.StatusCode);

        var content2 = await allocResponse2.Content.ReadAsStringAsync();
        using var doc2 = JsonDocument.Parse(content2);
        Assert.True(doc2.RootElement.GetProperty("chunksRetained").GetInt32() >= 2);

        // 3. Liberar memoria acumulada (/api/stress/memory/clear)
        var clearResponse = await client.PostAsync("/api/stress/memory/clear", null);
        Assert.Equal(HttpStatusCode.OK, clearResponse.StatusCode);

        var clearContent = await clearResponse.Content.ReadAsStringAsync();
        using var clearDoc = JsonDocument.Parse(clearContent);
        Assert.Contains("Cleared", clearDoc.RootElement.GetProperty("message").GetString());
    }
}
