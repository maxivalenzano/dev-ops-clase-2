using System.Text.Json;
using Backend.Models;
using Backend.Services;
using Moq;
using StackExchange.Redis;
using Xunit;

namespace Backend.Tests;

public class TaskServiceTests
{
    private const string TasksHashKey = "tasks";

    [Fact]
    public async Task CreateTaskAsync_WithValidInput_PersistsToRedisAndReturnsTask()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);
        var title = "Configurar SAST con CodeQL";
        var nodeName = "backend-dotnet-1";

        mockDb.Setup(d => d.HashSetAsync(
            TasksHashKey,
            It.IsAny<RedisValue>(),
            It.IsAny<RedisValue>(),
            When.Always,
            CommandFlags.None
        )).ReturnsAsync(true);

        // Act
        var result = await service.CreateTaskAsync(title, nodeName);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(title, result.Title);
        Assert.Equal(nodeName, result.CreatedByNode);
        Assert.False(result.IsCompleted);

        mockDb.Verify(d => d.HashSetAsync(
            TasksHashKey,
            result.Id,
            It.Is<RedisValue>(v => v.ToString().Contains(title)),
            When.Always,
            CommandFlags.None
        ), Times.Once);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CreateTaskAsync_WithInvalidTitle_ThrowsArgumentException(string? invalidTitle)
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(() => service.CreateTaskAsync(invalidTitle!, "node-1"));
        mockDb.Verify(d => d.HashSetAsync(It.IsAny<RedisKey>(), It.IsAny<RedisValue>(), It.IsAny<RedisValue>(), It.IsAny<When>(), It.IsAny<CommandFlags>()), Times.Never);
    }

    [Fact]
    public async Task GetAllTasksAsync_ReturnsAllStoredTasksOrderedByCreatedAtDescending()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);

        var task1 = new TaskItem("Tarea 1", "node-1") { CreatedAt = DateTime.UtcNow.AddMinutes(-10) };
        var task2 = new TaskItem("Tarea 2", "node-2") { CreatedAt = DateTime.UtcNow.AddMinutes(-5) };

        var hashEntries = new HashEntry[]
        {
            new(task1.Id, JsonSerializer.Serialize(task1)),
            new(task2.Id, JsonSerializer.Serialize(task2))
        };

        mockDb.Setup(d => d.HashGetAllAsync(TasksHashKey, CommandFlags.None))
              .ReturnsAsync(hashEntries);

        // Act
        var result = (await service.GetAllTasksAsync()).ToList();

        // Assert
        Assert.Equal(2, result.Count);
        // Ordenado descendentemente por CreatedAt: task2 primero, luego task1
        Assert.Equal(task2.Id, result[0].Id);
        Assert.Equal(task1.Id, result[1].Id);
    }

    [Fact]
    public async Task GetTaskByIdAsync_WhenTaskExists_ReturnsTask()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);

        var task = new TaskItem("Tarea Individual", "node-1");
        var taskJson = JsonSerializer.Serialize(task);

        mockDb.Setup(d => d.HashGetAsync(TasksHashKey, task.Id, CommandFlags.None))
              .ReturnsAsync(taskJson);

        // Act
        var result = await service.GetTaskByIdAsync(task.Id);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(task.Id, result.Id);
        Assert.Equal("Tarea Individual", result.Title);
    }

    [Fact]
    public async Task GetTaskByIdAsync_WhenTaskDoesNotExist_ReturnsNull()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);

        mockDb.Setup(d => d.HashGetAsync(TasksHashKey, "not-found", CommandFlags.None))
              .ReturnsAsync(RedisValue.Null);

        // Act
        var result = await service.GetTaskByIdAsync("not-found");

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task ToggleTaskAsync_WhenTaskExists_InvertsCompletionAndUpdatesRedis()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);

        var existingTask = new TaskItem("Probar Toggle", "node-1") { IsCompleted = false };
        var existingJson = JsonSerializer.Serialize(existingTask);

        mockDb.Setup(d => d.HashGetAsync(TasksHashKey, existingTask.Id, CommandFlags.None))
              .ReturnsAsync(existingJson);

        mockDb.Setup(d => d.HashSetAsync(
            TasksHashKey,
            existingTask.Id,
            It.IsAny<RedisValue>(),
            When.Always,
            CommandFlags.None
        )).ReturnsAsync(false);

        // Act
        var updated = await service.ToggleTaskAsync(existingTask.Id);

        // Assert
        Assert.NotNull(updated);
        Assert.True(updated.IsCompleted);

        mockDb.Verify(d => d.HashSetAsync(
            TasksHashKey,
            existingTask.Id,
            It.Is<RedisValue>(v => v.ToString().Contains("\"isCompleted\":true")),
            When.Always,
            CommandFlags.None
        ), Times.Once);
    }

    [Fact]
    public async Task ToggleTaskAsync_WhenTaskDoesNotExist_ReturnsNull()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);
        var nonExistentId = "unknown-id";

        mockDb.Setup(d => d.HashGetAsync(TasksHashKey, nonExistentId, CommandFlags.None))
              .ReturnsAsync(RedisValue.Null);

        // Act
        var result = await service.ToggleTaskAsync(nonExistentId);

        // Assert
        Assert.Null(result);
        mockDb.Verify(d => d.HashSetAsync(It.IsAny<RedisKey>(), It.IsAny<RedisValue>(), It.IsAny<RedisValue>(), It.IsAny<When>(), It.IsAny<CommandFlags>()), Times.Never);
    }

    [Fact]
    public async Task DeleteTaskAsync_WhenTaskExists_ReturnsTrue()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);
        var taskId = "task-to-delete";

        mockDb.Setup(d => d.HashDeleteAsync(TasksHashKey, taskId, CommandFlags.None))
              .ReturnsAsync(true);

        // Act
        var result = await service.DeleteTaskAsync(taskId);

        // Assert
        Assert.True(result);
        mockDb.Verify(d => d.HashDeleteAsync(TasksHashKey, taskId, CommandFlags.None), Times.Once);
    }

    [Fact]
    public async Task DeleteTaskAsync_WhenTaskDoesNotExist_ReturnsFalse()
    {
        // Arrange
        var mockDb = new Mock<IDatabase>();
        var service = new TaskService(mockDb.Object);
        var taskId = "non-existent";

        mockDb.Setup(d => d.HashDeleteAsync(TasksHashKey, taskId, CommandFlags.None))
              .ReturnsAsync(false);

        // Act
        var result = await service.DeleteTaskAsync(taskId);

        // Assert
        Assert.False(result);
        mockDb.Verify(d => d.HashDeleteAsync(TasksHashKey, taskId, CommandFlags.None), Times.Once);
    }

    [Fact]
    public async Task InMemoryFallback_OperatesSeamlesslyWhenRedisNotConnected()
    {
        // Arrange (sin pasar IDatabase ni Redis)
        var inMemoryService = new TaskService((IConnectionMultiplexer?)null);

        // Act 1: Crear tareas
        var task1 = await inMemoryService.CreateTaskAsync("Tarea en memoria 1", "local-node");
        var task2 = await inMemoryService.CreateTaskAsync("Tarea en memoria 2", "local-node");

        // Assert 1: Listar
        var list = (await inMemoryService.GetAllTasksAsync()).ToList();
        Assert.Equal(2, list.Count);

        // Act 2: Toggle
        var toggled = await inMemoryService.ToggleTaskAsync(task1.Id);
        Assert.NotNull(toggled);
        Assert.True(toggled.IsCompleted);

        // Act 3: Eliminar
        var deleted = await inMemoryService.DeleteTaskAsync(task2.Id);
        Assert.True(deleted);

        var remaining = (await inMemoryService.GetAllTasksAsync()).ToList();
        Assert.Single(remaining);
        Assert.Equal(task1.Id, remaining[0].Id);
    }
}
