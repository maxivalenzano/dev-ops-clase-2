using Backend.Models;

namespace Backend.Services;

public interface ITaskService
{
    Task<IEnumerable<TaskItem>> GetAllTasksAsync(CancellationToken cancellationToken = default);
    Task<TaskItem?> GetTaskByIdAsync(string id, CancellationToken cancellationToken = default);
    Task<TaskItem> CreateTaskAsync(string title, string nodeName, int priority = 2, CancellationToken cancellationToken = default);
    Task<TaskItem?> ToggleTaskAsync(string id, CancellationToken cancellationToken = default);
    Task<bool> DeleteTaskAsync(string id, CancellationToken cancellationToken = default);
}
