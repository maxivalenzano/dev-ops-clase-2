using Microsoft.EntityFrameworkCore;

namespace Backend.Data;

public static class DatabaseReadiness
{
    public static async Task<object> CheckAsync(AppDbContext db)
    {
        var applied = (await db.Database.GetAppliedMigrationsAsync()).ToArray();
        var known = db.Database.GetMigrations().ToArray();
        var minimum = db.Compatibility.Release switch { "P1" => 1, "P2" => 2, _ => 4 };
        // Only a known additive migration prefix is compatible. Future unknown changes need a new review.
        if (applied.Length < minimum || applied.Length > known.Length || !applied.SequenceEqual(known.Take(applied.Length)))
            throw new InvalidOperationException("Database schema is outside this application's compatibility range.");
        // Executes an authenticated query including every column this release needs, even for an empty table.
        await db.Tasks.AsNoTracking().Take(1).ToListAsync();
        return new { status = "UP", storage = "PostgreSQL", release = db.Compatibility.Release, schema = applied.Last() };
    }
}
