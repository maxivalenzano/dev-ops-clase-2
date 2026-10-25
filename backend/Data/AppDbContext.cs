using Backend.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace Backend.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options, SchemaCompatibility compatibility) : DbContext(options)
{
    public SchemaCompatibility Compatibility => compatibility;
    public DbSet<TaskItem> Tasks => Set<TaskItem>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        => optionsBuilder.ReplaceService<IModelCacheKeyFactory, ReleaseModelCacheKeyFactory>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var entity = modelBuilder.Entity<TaskItem>();
        entity.ToTable("tasks");
        entity.HasKey(x => x.Id);
        entity.Property(x => x.Id).HasColumnName("id").HasConversion(v => Guid.Parse(v), v => v.ToString()).HasColumnType("uuid");
        entity.Property(x => x.Title).HasColumnName("title").IsRequired();
        entity.Property(x => x.IsCompleted).HasColumnName("is_completed");
        entity.Property(x => x.CreatedByNode).HasColumnName("created_by_node").IsRequired();
        entity.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("timestamp with time zone");
        if (!compatibility.HasPriority) entity.Ignore(x => x.Priority);
        else
        {
            entity.Property(x => x.Priority).HasColumnName("priority").HasDefaultValue(2)
                .IsRequired(compatibility.RequiresPriority);
            if (compatibility.RequiresPriority)
                entity.ToTable(t => t.HasCheckConstraint("ck_tasks_priority", "priority BETWEEN 1 AND 3"));
        }
    }
}

public sealed class ReleaseModelCacheKeyFactory : IModelCacheKeyFactory
{
    public object Create(DbContext context, bool designTime)
        => context is AppDbContext app ? (context.GetType(), app.Compatibility.Release, designTime) : (object)(context.GetType(), designTime);
}
