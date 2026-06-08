using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RelativeMultiplePatients : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Relatives_Patients_PatientId",
                table: "Relatives");

            migrationBuilder.DropIndex(
                name: "IX_Relatives_PatientId",
                table: "Relatives");

            migrationBuilder.DropColumn(
                name: "PatientId",
                table: "Relatives");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PatientId",
                table: "Relatives",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Relatives_PatientId",
                table: "Relatives",
                column: "PatientId");

            migrationBuilder.AddForeignKey(
                name: "FK_Relatives_Patients_PatientId",
                table: "Relatives",
                column: "PatientId",
                principalTable: "Patients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
