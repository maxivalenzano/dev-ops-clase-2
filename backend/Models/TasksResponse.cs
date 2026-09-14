using System.Text.Json.Serialization;

namespace Backend.Models;

public record TasksResponse(
    [property: JsonPropertyName("servedByNode")] string ServedByNode,
    [property: JsonPropertyName("totalCount")] int TotalCount,
    [property: JsonPropertyName("tasks")] IEnumerable<TaskItem> Tasks
);
