using System.Text.Json.Serialization;

namespace Backend.Models;

public record CreateTaskRequest(
    [property: JsonPropertyName("title")] string? Title
);
