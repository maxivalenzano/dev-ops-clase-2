using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TaskItem> Tasks => Set<TaskItem>();

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
        entity.Property(x => x.Priority).HasColumnName("priority").HasDefaultValue(2).IsRequired();
        entity.ToTable(t => t.HasCheckConstraint("ck_tasks_priority", "priority BETWEEN 1 AND 3"));
    }
}
