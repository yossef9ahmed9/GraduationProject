using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeedFollowUpStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Set all existing follow-ups to 'Pending' so old data is valid
            migrationBuilder.Sql(
                "UPDATE [FollowUps] SET [Status] = 'Pending' WHERE [Status] = '' OR [Status] IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("UPDATE [FollowUps] SET [Status] = ''");
        }
    }
}
