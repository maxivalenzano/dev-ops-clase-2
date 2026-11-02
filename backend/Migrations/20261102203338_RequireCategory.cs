using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class RequireCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddCheckConstraint(
                name: "ck_tasks_category",
                table: "tasks",
                sql: "category IN ('general', 'infraestructura', 'seguridad')");

            migrationBuilder.Sql("""
                ALTER TABLE tasks
                ALTER COLUMN category SET NOT NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                ALTER TABLE tasks
                ALTER COLUMN category DROP NOT NULL;
                """);

            migrationBuilder.DropCheckConstraint(
                name: "ck_tasks_category",
                table: "tasks");

        }
    }
}
