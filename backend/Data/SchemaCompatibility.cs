namespace Backend.Data;

public sealed class SchemaCompatibility
{
    public string Release { get; }
    public bool HasPriority => Release != "P1";
    public bool RequiresPriority => Release == "P3";
    public SchemaCompatibility(string? release = null)
    {
        Release = release ?? Environment.GetEnvironmentVariable("TASK_RELEASE") ?? "P3";
        if (Release is not ("P1" or "P2" or "P3"))
            throw new InvalidOperationException("TASK_RELEASE must be P1, P2 or P3.");
    }
}
