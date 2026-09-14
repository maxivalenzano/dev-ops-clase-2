using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Backend.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Backend.Tests;

public class TaskEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public TaskEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task TaskEndpoints_FullCrudFlow_SucceedsAccordingToContract()
    {
        // Arrange
        var client = _factory.CreateClient();

        // 1. Validar fallo con título vacío (400 Bad Request)
        var invalidCreateResponse = await client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("   "));
        Assert.Equal(HttpStatusCode.BadRequest, invalidCreateResponse.StatusCode);

        // 2. Crear nueva tarea (201 Created)
        var createResponse = await client.PostAsJsonAsync("/api/tasks", new CreateTaskRequest("Integración continua"));
        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);

        var createdTask = await createResponse.Content.ReadFromJsonAsync<TaskItem>();
        Assert.NotNull(createdTask);
        Assert.Equal("Integración continua", createdTask.Title);
        Assert.False(createdTask.IsCompleted);
        Assert.False(string.IsNullOrWhiteSpace(createdTask.CreatedByNode));
        Assert.False(string.IsNullOrWhiteSpace(createdTask.Id));

        // 3. Listar tareas (200 OK) y verificar envoltura con servedByNode
        var listResponse = await client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, listResponse.StatusCode);

        var listWrapper = await listResponse.Content.ReadFromJsonAsync<TasksResponse>();
        Assert.NotNull(listWrapper);
        Assert.False(string.IsNullOrWhiteSpace(listWrapper.ServedByNode));
        Assert.True(listWrapper.TotalCount >= 1);
        Assert.Contains(listWrapper.Tasks, t => t.Id == createdTask.Id);

        // 4. Toggle estado de tarea (200 OK)
        var toggleResponse = await client.PutAsync($"/api/tasks/{createdTask.Id}/toggle", null);
        Assert.Equal(HttpStatusCode.OK, toggleResponse.StatusCode);

        var toggledTask = await toggleResponse.Content.ReadFromJsonAsync<TaskItem>();
        Assert.NotNull(toggledTask);
        Assert.Equal(createdTask.Id, toggledTask.Id);
        Assert.True(toggledTask.IsCompleted);

        // 5. Eliminar tarea (200 OK)
        var deleteResponse = await client.DeleteAsync($"/api/tasks/{createdTask.Id}");
        Assert.Equal(HttpStatusCode.OK, deleteResponse.StatusCode);

        // 6. Intentar togglear tarea inexistente / eliminada (404 Not Found)
        var notFoundToggle = await client.PutAsync($"/api/tasks/{createdTask.Id}/toggle", null);
        Assert.Equal(HttpStatusCode.NotFound, notFoundToggle.StatusCode);
    }
}
