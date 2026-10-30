using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Backend.Services;

public sealed class PostgresTaskService(AppDbContext db) : ITaskService
{
    public async Task<IEnumerable<TaskItem>> GetAllTasksAsync(CancellationToken cancellationToken = default)
        => (await db.Tasks.AsNoTracking().OrderByDescending(x => x.CreatedAt).ToListAsync(cancellationToken)).Select(x => Normalize(x)!);

    public async Task<TaskItem?> GetTaskByIdAsync(string id, CancellationToken cancellationToken = default)
        => !Guid.TryParse(id, out _) ? null : Normalize(await db.Tasks.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, cancellationToken));

    public async Task<TaskItem> CreateTaskAsync(string title, string nodeName, int priority = 2, CancellationToken cancellationToken = default)
    {
        if (priority is < 1 or > 3) throw new ArgumentOutOfRangeException(nameof(priority));
        var task = new TaskItem(title, nodeName) { Priority = priority };
        db.Tasks.Add(task);
        await db.SaveChangesAsync(cancellationToken);
        return task;
    }

    public async Task<TaskItem?> ToggleTaskAsync(string id, CancellationToken cancellationToken = default)
    {
        if (!Guid.TryParse(id, out var uuid)) return null;
        await db.Database.OpenConnectionAsync(cancellationToken);
        await using var command = db.Database.GetDbConnection().CreateCommand();
        // RETURNING returns the value committed by this atomic statement, even under concurrent toggles.
        command.CommandText = "UPDATE tasks SET is_completed = NOT is_completed WHERE id = @id " +
                              "RETURNING id, title, is_completed, created_by_node, created_at, priority";
        command.Parameters.Add(new NpgsqlParameter("id", uuid));
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new TaskItem(reader.GetGuid(0).ToString(), reader.GetString(1), reader.GetBoolean(2), reader.GetString(3), reader.GetDateTime(4))
        {
            Priority = reader.GetInt32(5)
        };
    }

    public async Task<bool> DeleteTaskAsync(string id, CancellationToken cancellationToken = default)
        => Guid.TryParse(id, out _) && await db.Tasks.Where(x => x.Id == id).ExecuteDeleteAsync(cancellationToken) != 0;

    private static TaskItem? Normalize(TaskItem? task)
    {
        if (task is not null) task.Priority ??= 2;
        return task;
    }
}
