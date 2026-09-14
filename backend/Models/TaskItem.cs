using System.Text.Json.Serialization;

namespace Backend.Models;

public class TaskItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("isCompleted")]
    public bool IsCompleted { get; set; }

    [JsonPropertyName("createdByNode")]
    public string CreatedByNode { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public TaskItem()
    {
    }

    public TaskItem(string title, string createdByNode)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ArgumentException("Title cannot be null or whitespace.", nameof(title));
        }

        Id = Guid.NewGuid().ToString();
        Title = title.Trim();
        IsCompleted = false;
        CreatedByNode = createdByNode ?? string.Empty;
        CreatedAt = DateTime.UtcNow;
    }

    public TaskItem(string id, string title, bool isCompleted, string createdByNode, DateTime createdAt)
    {
        Id = id;
        Title = title;
        IsCompleted = isCompleted;
        CreatedByNode = createdByNode;
        CreatedAt = createdAt;
    }

    public void Toggle()
    {
        IsCompleted = !IsCompleted;
    }
}
