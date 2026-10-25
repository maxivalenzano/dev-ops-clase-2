using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Backend.Services;

public sealed class PostgresTaskService(AppDbContext db) : ITaskService
{
    public async Task<IEnumerable<TaskItem>> GetAllTasksAsync()
        => (await db.Tasks.AsNoTracking().OrderByDescending(x => x.CreatedAt).ToListAsync()).Select(x => Normalize(x)!);

    public async Task<TaskItem?> GetTaskByIdAsync(string id)
        => !Guid.TryParse(id, out _) ? null : Normalize(await db.Tasks.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id));

    public async Task<TaskItem> CreateTaskAsync(string title, string nodeName, int priority = 2)
    {
        if (priority is < 1 or > 3) throw new ArgumentOutOfRangeException(nameof(priority));
        var task = new TaskItem(title, nodeName) { Priority = priority };
        db.Tasks.Add(task);
        await db.SaveChangesAsync();
        return task;
    }

    public async Task<TaskItem?> ToggleTaskAsync(string id)
    {
        if (!Guid.TryParse(id, out var uuid)) return null;
        await db.Database.OpenConnectionAsync();
        await using var command = db.Database.GetDbConnection().CreateCommand();
        // RETURNING returns the value committed by this atomic statement, even under concurrent toggles.
        command.CommandText = "UPDATE tasks SET is_completed = NOT is_completed WHERE id = @id " +
                              "RETURNING id, title, is_completed, created_by_node, created_at" +
                              (db.Compatibility.HasPriority ? ", priority" : "");
        command.Parameters.Add(new NpgsqlParameter("id", uuid));
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;
        return new TaskItem(reader.GetGuid(0).ToString(), reader.GetString(1), reader.GetBoolean(2), reader.GetString(3), reader.GetDateTime(4))
        {
            Priority = db.Compatibility.HasPriority && !reader.IsDBNull(5) ? reader.GetInt32(5) : 2
        };
    }

    public async Task<bool> DeleteTaskAsync(string id)
        => Guid.TryParse(id, out _) && await db.Tasks.Where(x => x.Id == id).ExecuteDeleteAsync() != 0;

    private static TaskItem? Normalize(TaskItem? task)
    {
        if (task is not null) task.Priority ??= 2;
        return task;
    }
}
