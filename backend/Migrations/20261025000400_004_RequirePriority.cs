using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class _004_RequirePriority : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Keep the data transformation explicit in 003; SET NOT NULL must fail if backfill was skipped.
            // The existing DEFAULT 2 remains in place for P1 inserts that omit this column.
            migrationBuilder.Sql("ALTER TABLE tasks ALTER COLUMN priority SET NOT NULL");
            migrationBuilder.AddCheckConstraint(
                name: "ck_tasks_priority",
                table: "tasks",
                sql: "priority BETWEEN 1 AND 3");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_tasks_priority",
                table: "tasks");

            migrationBuilder.AlterColumn<int>(
                name: "priority",
                table: "tasks",
                type: "integer",
                nullable: true,
                defaultValue: 2,
                oldClrType: typeof(int),
                oldType: "integer",
                oldDefaultValue: 2);
        }
    }
}
