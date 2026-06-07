using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddClinicAndLabLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── Doctor: remove IsAvailable, add clinic fields ──────
            migrationBuilder.DropColumn(
                name: "IsAvailable",
                table: "Doctors");

            migrationBuilder.AddColumn<string>(
                name: "ClinicName",
                table: "Doctors",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ClinicAddress",
                table: "Doctors",
                type: "nvarchar(250)",
                maxLength: 250,
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "ClinicLatitude",
                table: "Doctors",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "ClinicLongitude",
                table: "Doctors",
                type: "float",
                nullable: true);

            // ── Lab: add coordinates ───────────────────────────────
            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "Labs",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "Labs",
                type: "float",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // ── Doctor: restore IsAvailable, remove clinic fields ──
            migrationBuilder.AddColumn<bool>(
                name: "IsAvailable",
                table: "Doctors",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.DropColumn(name: "ClinicName",      table: "Doctors");
            migrationBuilder.DropColumn(name: "ClinicAddress",   table: "Doctors");
            migrationBuilder.DropColumn(name: "ClinicLatitude",  table: "Doctors");
            migrationBuilder.DropColumn(name: "ClinicLongitude", table: "Doctors");

            // ── Lab: remove coordinates ────────────────────────────
            migrationBuilder.DropColumn(name: "Latitude",  table: "Labs");
            migrationBuilder.DropColumn(name: "Longitude", table: "Labs");
        }
    }
}
