using Backend.Models;

namespace Backend.Services;

public interface ITaskService
{
    Task<IEnumerable<TaskItem>> GetAllTasksAsync();
    Task<TaskItem?> GetTaskByIdAsync(string id);
    Task<TaskItem> CreateTaskAsync(string title, string nodeName);
    Task<TaskItem?> ToggleTaskAsync(string id);
    Task<bool> DeleteTaskAsync(string id);
}
