using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPatientToVitalSigns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_VitalSigns_Sensors_SensorId",
                table: "VitalSigns");

            migrationBuilder.AddColumn<int>(
                name: "PatientId",
                table: "VitalSigns",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_VitalSigns_PatientId",
                table: "VitalSigns",
                column: "PatientId");

            migrationBuilder.AddForeignKey(
                name: "FK_VitalSigns_Patients_PatientId",
                table: "VitalSigns",
                column: "PatientId",
                principalTable: "Patients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_VitalSigns_Sensors_SensorId",
                table: "VitalSigns",
                column: "SensorId",
                principalTable: "Sensors",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_VitalSigns_Patients_PatientId",
                table: "VitalSigns");

            migrationBuilder.DropForeignKey(
                name: "FK_VitalSigns_Sensors_SensorId",
                table: "VitalSigns");

            migrationBuilder.DropIndex(
                name: "IX_VitalSigns_PatientId",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "PatientId",
                table: "VitalSigns");

            migrationBuilder.AddForeignKey(
                name: "FK_VitalSigns_Sensors_SensorId",
                table: "VitalSigns",
                column: "SensorId",
                principalTable: "Sensors",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
