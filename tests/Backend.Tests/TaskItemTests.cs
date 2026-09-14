using System.Text.Json;
using Backend.Models;
using Xunit;

namespace Backend.Tests;

public class TaskItemTests
{
    [Fact]
    public void Constructor_Default_InitializesWithDefaultValues()
    {
        // Act
        var task = new TaskItem();

        // Assert
        Assert.False(string.IsNullOrWhiteSpace(task.Id));
        Assert.True(Guid.TryParse(task.Id, out _));
        Assert.Empty(task.Title);
        Assert.False(task.IsCompleted);
        Assert.Empty(task.CreatedByNode);
        Assert.True(task.CreatedAt <= DateTime.UtcNow);
    }

    [Fact]
    public void Constructor_WithValidArguments_SetsPropertiesProperly()
    {
        // Arrange
        var title = "Implementar CI en GitHub Actions";
        var nodeName = "backend-dotnet-1";
        var before = DateTime.UtcNow.AddSeconds(-1);

        // Act
        var task = new TaskItem(title, nodeName);

        // Assert
        Assert.False(string.IsNullOrWhiteSpace(task.Id));
        Assert.Equal("Implementar CI en GitHub Actions", task.Title);
        Assert.Equal("backend-dotnet-1", task.CreatedByNode);
        Assert.False(task.IsCompleted);
        Assert.True(task.CreatedAt >= before && task.CreatedAt <= DateTime.UtcNow.AddSeconds(1));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Constructor_WithInvalidTitle_ThrowsArgumentException(string? invalidTitle)
    {
        // Act & Assert
        var ex = Assert.Throws<ArgumentException>(() => new TaskItem(invalidTitle!, "node-1"));
        Assert.Equal("title", ex.ParamName);
    }

    [Fact]
    public void Toggle_WhenCalledMultipleTimes_InvertsIsCompletedState()
    {
        // Arrange
        var task = new TaskItem("Test Toggle", "backend-1");
        Assert.False(task.IsCompleted);

        // Act & Assert
        task.Toggle();
        Assert.True(task.IsCompleted);

        task.Toggle();
        Assert.False(task.IsCompleted);
    }

    [Fact]
    public void TaskItem_JsonSerialization_MatchesAgreedContract()
    {
        // Arrange
        var task = new TaskItem("task-fixed-uuid-1234", "Contrato de Tarea", true, "backend-dotnet-2", new DateTime(2026, 9, 13, 21, 15, 0, DateTimeKind.Utc));

        // Act
        var json = JsonSerializer.Serialize(task);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // Assert
        Assert.Equal("task-fixed-uuid-1234", root.GetProperty("id").GetString());
        Assert.Equal("Contrato de Tarea", root.GetProperty("title").GetString());
        Assert.True(root.GetProperty("isCompleted").GetBoolean());
        Assert.Equal("backend-dotnet-2", root.GetProperty("createdByNode").GetString());
        Assert.Equal("2026-09-13T21:15:00Z", root.GetProperty("createdAt").GetString());
    }

    [Fact]
    public void TaskItem_JsonDeserialization_PreservesState()
    {
        // Arrange
        var json = """
        {
            "id": "task-test-5678",
            "title": "Verificar tolerancia a fallos",
            "isCompleted": false,
            "createdByNode": "backend-dotnet-3",
            "createdAt": "2026-09-13T20:05:00Z"
        }
        """;

        // Act
        var task = JsonSerializer.Deserialize<TaskItem>(json);

        // Assert
        Assert.NotNull(task);
        Assert.Equal("task-test-5678", task.Id);
        Assert.Equal("Verificar tolerancia a fallos", task.Title);
        Assert.False(task.IsCompleted);
        Assert.Equal("backend-dotnet-3", task.CreatedByNode);
        Assert.Equal(new DateTime(2026, 9, 13, 20, 5, 0, DateTimeKind.Utc), task.CreatedAt);
    }
}
