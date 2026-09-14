using System.Collections.Concurrent;
using System.Text.Json;
using Backend.Models;
using StackExchange.Redis;

namespace Backend.Services;

public class TaskService : ITaskService
{
    private const string TasksHashKey = "tasks";
    private readonly IDatabase? _database;
    private readonly ConcurrentDictionary<string, TaskItem> _inMemoryFallback = new();

    public TaskService(IConnectionMultiplexer? redis = null)
    {
        if (redis != null)
        {
            try
            {
                _database = redis.GetDatabase();
            }
            catch
            {
                // Fallback to in-memory if Redis connection is not ready
                _database = null;
            }
        }
    }

    public TaskService(IDatabase database)
    {
        _database = database ?? throw new ArgumentNullException(nameof(database));
    }

    public async Task<IEnumerable<TaskItem>> GetAllTasksAsync()
    {
        if (_database != null)
        {
            var entries = await _database.HashGetAllAsync(TasksHashKey);
            var tasks = new List<TaskItem>();

            foreach (var entry in entries)
            {
                if (!entry.Value.IsNullOrEmpty)
                {
                    var item = JsonSerializer.Deserialize<TaskItem>(entry.Value.ToString()!);
                    if (item != null)
                    {
                        tasks.Add(item);
                    }
                }
            }

            return tasks.OrderByDescending(t => t.CreatedAt);
        }

        return _inMemoryFallback.Values.OrderByDescending(t => t.CreatedAt);
    }

    public async Task<TaskItem> CreateTaskAsync(string title, string nodeName)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ArgumentException("Title cannot be null or whitespace.", nameof(title));
        }

        var task = new TaskItem(title, nodeName);

        if (_database != null)
        {
            var json = JsonSerializer.Serialize(task);
            await _database.HashSetAsync(TasksHashKey, task.Id, json);
        }
        else
        {
            _inMemoryFallback[task.Id] = task;
        }

        return task;
    }

    public async Task<TaskItem?> ToggleTaskAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }

        if (_database != null)
        {
            var value = await _database.HashGetAsync(TasksHashKey, id);
            if (value.IsNullOrEmpty)
            {
                return null;
            }

            var task = JsonSerializer.Deserialize<TaskItem>(value.ToString()!);
            if (task == null)
            {
                return null;
            }

            task.Toggle();

            var updatedJson = JsonSerializer.Serialize(task);
            await _database.HashSetAsync(TasksHashKey, task.Id, updatedJson);

            return task;
        }

        if (_inMemoryFallback.TryGetValue(id, out var inMemoryTask))
        {
            inMemoryTask.Toggle();
            return inMemoryTask;
        }

        return null;
    }

    public async Task<bool> DeleteTaskAsync(string id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return false;
        }

        if (_database != null)
        {
            return await _database.HashDeleteAsync(TasksHashKey, id);
        }

        return _inMemoryFallback.TryRemove(id, out _);
    }
}
