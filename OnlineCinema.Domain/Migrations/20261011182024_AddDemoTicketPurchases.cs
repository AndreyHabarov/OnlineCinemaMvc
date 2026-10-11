using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace OnlineCinema.Domain.Migrations
{
    /// <inheritdoc />
    public partial class AddDemoTicketPurchases : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Tickets_SessionId",
                table: "Tickets");

            migrationBuilder.DropIndex(
                name: "IX_Seats_HallId",
                table: "Seats");

            migrationBuilder.AddColumn<int>(
                name: "PurchaseOrderId",
                table: "Tickets",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PurchaseOrders",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    PublicId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<int>(type: "integer", nullable: false),
                    SessionId = table.Column<int>(type: "integer", nullable: false),
                    Total = table.Column<int>(type: "integer", nullable: false),
                    ViewerAge = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    MovieName = table.Column<string>(type: "text", nullable: false),
                    HallName = table.Column<string>(type: "text", nullable: false),
                    StartsAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PurchaseOrders", x => x.Id);
                    table.CheckConstraint("CK_PurchaseOrders_Total", "\"Total\" > 0");
                    table.ForeignKey(
                        name: "FK_PurchaseOrders_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseOrders_Sessions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Sessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Tickets_PurchaseOrderId",
                table: "Tickets",
                column: "PurchaseOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_Tickets_SessionId_SeatId",
                table: "Tickets",
                columns: new[] { "SessionId", "SeatId" },
                unique: true,
                filter: "\"Status\" IN (0, 1)");

            migrationBuilder.CreateIndex(
                name: "IX_Seats_HallId_Row_Number",
                table: "Seats",
                columns: new[] { "HallId", "Row", "Number" },
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Seats_Position",
                table: "Seats",
                sql: "\"Row\" > 0 AND \"Number\" > 0 AND \"Price\" >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_PublicId",
                table: "PurchaseOrders",
                column: "PublicId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_SessionId",
                table: "PurchaseOrders",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_UserId_RequestId",
                table: "PurchaseOrders",
                columns: new[] { "UserId", "RequestId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Tickets_PurchaseOrders_PurchaseOrderId",
                table: "Tickets",
                column: "PurchaseOrderId",
                principalTable: "PurchaseOrders",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Tickets_PurchaseOrders_PurchaseOrderId",
                table: "Tickets");

            migrationBuilder.DropTable(
                name: "PurchaseOrders");

            migrationBuilder.DropIndex(
                name: "IX_Tickets_PurchaseOrderId",
                table: "Tickets");

            migrationBuilder.DropIndex(
                name: "IX_Tickets_SessionId_SeatId",
                table: "Tickets");

            migrationBuilder.DropIndex(
                name: "IX_Seats_HallId_Row_Number",
                table: "Seats");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Seats_Position",
                table: "Seats");

            migrationBuilder.DropColumn(
                name: "PurchaseOrderId",
                table: "Tickets");

            migrationBuilder.CreateIndex(
                name: "IX_Tickets_SessionId",
                table: "Tickets",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_Seats_HallId",
                table: "Seats",
                column: "HallId");
        }
    }
}
