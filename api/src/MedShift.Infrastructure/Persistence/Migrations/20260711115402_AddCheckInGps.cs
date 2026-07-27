using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MedShift.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCheckInGps : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "AccuracyMeters",
                table: "CheckInSessions",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "DistanceMeters",
                table: "CheckInSessions",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "CheckInSessions",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "CheckInSessions",
                type: "float",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AccuracyMeters",
                table: "CheckInSessions");

            migrationBuilder.DropColumn(
                name: "DistanceMeters",
                table: "CheckInSessions");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "CheckInSessions");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "CheckInSessions");
        }
    }
}
