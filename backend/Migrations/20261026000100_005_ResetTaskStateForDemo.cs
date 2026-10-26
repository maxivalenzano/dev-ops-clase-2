using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class _005_ResetTaskStateForDemo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                CREATE TABLE task_state_before_priority_test (
                    id uuid PRIMARY KEY,
                    priority integer NOT NULL,
                    is_completed boolean NOT NULL
                );

                INSERT INTO task_state_before_priority_test (id, priority, is_completed)
                SELECT id, priority, is_completed FROM tasks;

                UPDATE tasks SET priority = 1, is_completed = false;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                UPDATE tasks AS task
                SET priority = previous.priority,
                    is_completed = previous.is_completed
                FROM task_state_before_priority_test AS previous
                WHERE task.id = previous.id;

                DROP TABLE task_state_before_priority_test;
                """);
        }
    }
}
