using Microsoft.EntityFrameworkCore;

namespace Backend.Data;

public static class DatabaseReadiness
{
    public static async Task<object> CheckAsync(AppDbContext db, CancellationToken cancellationToken = default)
    {
        var applied = (await db.Database.GetAppliedMigrationsAsync(cancellationToken)).ToArray();
        var known = db.Database.GetMigrations().ToArray();
        // Require this application's migrations, while allowing a previous app build to run
        // against later migrations during the deploy/rollback window.
        if (known.Length == 0 || applied.Length < known.Length || !applied.Take(known.Length).SequenceEqual(known))
            throw new InvalidOperationException("Database migrations do not contain this application's migration history.");
        // Executes an authenticated query including every column this release needs, even for an empty table.
        await db.Tasks.AsNoTracking().Take(1).ToListAsync(cancellationToken);
        return new { status = "UP", storage = "PostgreSQL", schema = applied.Last() };
    }
}
