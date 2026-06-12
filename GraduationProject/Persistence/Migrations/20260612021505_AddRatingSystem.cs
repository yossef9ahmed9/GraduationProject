using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GraduationProject.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRatingSystem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Ratings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PatientId    = table.Column<int>(type: "int", nullable: false),
                    DoctorId     = table.Column<int>(type: "int", nullable: true),
                    LabId        = table.Column<int>(type: "int", nullable: true),
                    Stars        = table.Column<double>(type: "float", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Ratings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Ratings_Doctors_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Ratings_Labs_LabId",
                        column: x => x.LabId,
                        principalTable: "Labs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Ratings_Patients_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // Unique: one rating per patient per doctor (only when DoctorId is not null)
            migrationBuilder.CreateIndex(
                name: "IX_Ratings_PatientId_DoctorId",
                table: "Ratings",
                columns: new[] { "PatientId", "DoctorId" },
                unique: true,
                filter: "[DoctorId] IS NOT NULL");

            // Unique: one rating per patient per lab (only when LabId is not null)
            migrationBuilder.CreateIndex(
                name: "IX_Ratings_PatientId_LabId",
                table: "Ratings",
                columns: new[] { "PatientId", "LabId" },
                unique: true,
                filter: "[LabId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Ratings_DoctorId",
                table: "Ratings",
                column: "DoctorId");

            migrationBuilder.CreateIndex(
                name: "IX_Ratings_LabId",
                table: "Ratings",
                column: "LabId");

            migrationBuilder.CreateIndex(
                name: "IX_Ratings_PatientId",
                table: "Ratings",
                column: "PatientId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "Ratings");
        }
    }
}
