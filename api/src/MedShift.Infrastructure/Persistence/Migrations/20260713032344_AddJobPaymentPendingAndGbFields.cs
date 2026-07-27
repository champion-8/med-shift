using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MedShift.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddJobPaymentPendingAndGbFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GbpReferenceNo",
                table: "JobPayments",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MerchantReference",
                table: "JobPayments",
                type: "nvarchar(15)",
                maxLength: 15,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_JobPayments_MerchantReference",
                table: "JobPayments",
                column: "MerchantReference");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_JobPayments_MerchantReference",
                table: "JobPayments");

            migrationBuilder.DropColumn(
                name: "GbpReferenceNo",
                table: "JobPayments");

            migrationBuilder.DropColumn(
                name: "MerchantReference",
                table: "JobPayments");
        }
    }
}
