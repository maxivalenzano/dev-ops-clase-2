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
            // Retained to preserve the migration ID already used by deployed databases.
            // The old demo-only data reset must not run automatically on a normal deployment.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Keep this historical data-reset migration non-destructive in both directions.
        }
    }
}
