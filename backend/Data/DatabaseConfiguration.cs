using Npgsql;

namespace Backend.Data;

public static class DatabaseConfiguration
{
    public static string ConnectionString(IConfiguration? configuration = null)
    {
        var secretFile = Environment.GetEnvironmentVariable("DATABASE_CONNECTION_FILE");
        var connection = !string.IsNullOrWhiteSpace(secretFile)
            ? File.ReadAllText(secretFile).Trim()
            : configuration?.GetConnectionString("Postgres")
              ?? Environment.GetEnvironmentVariable("ConnectionStrings__Postgres");
        if (string.IsNullOrWhiteSpace(connection))
            throw new InvalidOperationException("Configure DATABASE_CONNECTION_FILE or ConnectionStrings__Postgres.");
        var options = new NpgsqlConnectionStringBuilder(connection)
        {
            MaxPoolSize = 5,
            Timeout = 5,
            CommandTimeout = 30,
            IncludeErrorDetail = false
        };
        return options.ConnectionString;
    }
}
