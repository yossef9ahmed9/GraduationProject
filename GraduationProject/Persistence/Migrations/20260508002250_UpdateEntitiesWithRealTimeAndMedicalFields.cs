using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class UpdateEntitiesWithRealTimeAndMedicalFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
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

            migrationBuilder.AddColumn<double>(
                name: "OxygenSaturation",
                table: "VitalSigns",
                type: "float",
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

            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "Sensors",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastPing",
                table: "Sensors",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Email",
                table: "Relatives",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsPrimaryContact",
                table: "Relatives",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Allergies",
                table: "Patients",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BloodType",
                table: "Patients",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ChronicDiseases",
                table: "Patients",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsInEmergency",
                table: "Patients",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastLocationUpdate",
                table: "Patients",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "Patients",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "Patients",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "NextVisitDate",
                table: "FollowUps",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Severity",
                table: "FollowUps",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "HospitalName",
                table: "Doctors",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsAvailable",
                table: "Doctors",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "DriverName",
                table: "Ambulances",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "DriverPhone",
                table: "Ambulances",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "LastLocationUpdate",
                table: "Ambulances",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "Ambulances",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LicensePlate",
                table: "Ambulances",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "Ambulances",
                type: "float",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "EmergencyDispatches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DispatchedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ArrivedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ResolvedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    PatientLatitude = table.Column<double>(type: "float", nullable: false),
                    PatientLongitude = table.Column<double>(type: "float", nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PatientId = table.Column<int>(type: "int", nullable: false),
                    AmbulanceId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EmergencyDispatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EmergencyDispatches_Ambulances_AmbulanceId",
                        column: x => x.AmbulanceId,
                        principalTable: "Ambulances",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_EmergencyDispatches_Patients_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EmergencyDispatches_AmbulanceId",
                table: "EmergencyDispatches",
                column: "AmbulanceId");

            migrationBuilder.CreateIndex(
                name: "IX_EmergencyDispatches_PatientId",
                table: "EmergencyDispatches",
                column: "PatientId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EmergencyDispatches");

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
                name: "OxygenSaturation",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "RespiratoryRate",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "Temperature",
                table: "VitalSigns");

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "Sensors");

            migrationBuilder.DropColumn(
                name: "LastPing",
                table: "Sensors");

            migrationBuilder.DropColumn(
                name: "Email",
                table: "Relatives");

            migrationBuilder.DropColumn(
                name: "IsPrimaryContact",
                table: "Relatives");

            migrationBuilder.DropColumn(
                name: "Allergies",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "BloodType",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "ChronicDiseases",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "IsInEmergency",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "LastLocationUpdate",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Patients");

            migrationBuilder.DropColumn(
                name: "NextVisitDate",
                table: "FollowUps");

            migrationBuilder.DropColumn(
                name: "Severity",
                table: "FollowUps");

            migrationBuilder.DropColumn(
                name: "HospitalName",
                table: "Doctors");

            migrationBuilder.DropColumn(
                name: "IsAvailable",
                table: "Doctors");

            migrationBuilder.DropColumn(
                name: "DriverName",
                table: "Ambulances");

            migrationBuilder.DropColumn(
                name: "DriverPhone",
                table: "Ambulances");

            migrationBuilder.DropColumn(
                name: "LastLocationUpdate",
                table: "Ambulances");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Ambulances");

            migrationBuilder.DropColumn(
                name: "LicensePlate",
                table: "Ambulances");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Ambulances");
        }
    }
}
