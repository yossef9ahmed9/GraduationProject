using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveUnusedVitalSignsColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BloodGlucose",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "BloodPressureDiastolic",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "BloodPressureSystolic",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "RespiratoryRate",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "Temperature",
                table: "VitalSigns");

            migrationBuilder.AlterColumn<double>(
                name: "OxygenSaturation",
                table: "VitalSigns",
                type: "float",
                nullable: false,
                defaultValue: 0.0,
                oldClrType: typeof(double),
                oldType: "float",
                oldNullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<double>(
                name: "OxygenSaturation",
                table: "VitalSigns",
                type: "float",
                nullable: true,
                oldClrType: typeof(double),
                oldType: "float");

            migrationBuilder.AddColumn<double>(
                name: "BloodGlucose",
                table: "VitalSigns",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BloodPressureDiastolic",
                table: "VitalSigns",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BloodPressureSystolic",
                table: "VitalSigns",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RespiratoryRate",
                table: "VitalSigns",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Temperature",
                table: "VitalSigns",
                type: "float",
                nullable: true);
        }
    }
}
