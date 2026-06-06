using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddFcmTokens : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FcmToken",
                table: "Relatives",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FcmToken",
                table: "Patients",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FcmToken",
                table: "Doctors",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "LabAppointments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PatientId = table.Column<int>(type: "int", nullable: false),
                    LabId = table.Column<int>(type: "int", nullable: false),
                    TestNames = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    AppointmentDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LabAppointments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LabAppointments_Labs_LabId",
                        column: x => x.LabId,
                        principalTable: "Labs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LabAppointments_Patients_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LabAppointments_LabId",
                table: "LabAppointments",
                column: "LabId");

            migrationBuilder.CreateIndex(
                name: "IX_LabAppointments_PatientId",
                table: "LabAppointments",
                column: "PatientId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LabAppointments");

            migrationBuilder.DropColumn(
                name: "FcmToken",
                table: "Relatives");

            migrationBuilder.DropColumn(
                name: "FcmToken",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "FcmToken",
                table: "Doctors");
        }
    }
}
