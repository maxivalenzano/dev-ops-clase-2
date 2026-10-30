using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Backend.Data;

public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        // A local placeholder permits SQL/bundle generation without embedding deployment credentials.
        var configured = Environment.GetEnvironmentVariable("DATABASE_CONNECTION_FILE")
                         ?? Environment.GetEnvironmentVariable("ConnectionStrings__Postgres");
        var connection = configured is null
            ? "Host=localhost;Database=devops;Username=devops_migrator;Timeout=5;Command Timeout=30"
            : DatabaseConfiguration.ConnectionString();
        var options = new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(connection).Options;
        return new AppDbContext(options);
    }
}
