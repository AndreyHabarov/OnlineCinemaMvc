using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace OnlineCinema.Domain.Migrations
{
    /// <inheritdoc />
    public partial class ValidateAdminCatalog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Сохраняем первую старую ссылку и даём отдельный адрес остальным акциям.
            migrationBuilder.Sql(@"WITH duplicates AS (
                SELECT ""Id"", row_number() OVER (PARTITION BY lower(btrim(""Name"")) ORDER BY ""Id"") AS n
                FROM ""Promotions"")
                UPDATE ""Promotions"" AS p SET ""Name"" = p.""Name"" || '-' || p.""Id""
                FROM duplicates AS d WHERE p.""Id""=d.""Id"" AND d.n>1;");

            migrationBuilder.DropForeignKey(
                name: "FK_MovieGenres_Genres_GenreId",
                table: "MovieGenres");

            migrationBuilder.AddColumn<string>(
                name: "NormalizedName",
                table: "Promotions",
                type: "text",
                nullable: true,
                computedColumnSql: "lower(btrim(\"Name\"))",
                stored: true);

            migrationBuilder.AddColumn<string>(
                name: "NormalizedName",
                table: "Genres",
                type: "text",
                nullable: true,
                computedColumnSql: "lower(btrim(\"Name\"))",
                stored: true);

            migrationBuilder.CreateIndex(
                name: "IX_Promotions_NormalizedName",
                table: "Promotions",
                column: "NormalizedName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Genres_NormalizedName",
                table: "Genres",
                column: "NormalizedName",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_MovieGenres_Genres_GenreId",
                table: "MovieGenres",
                column: "GenreId",
                principalTable: "Genres",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MovieGenres_Genres_GenreId",
                table: "MovieGenres");

            migrationBuilder.DropIndex(
                name: "IX_Promotions_NormalizedName",
                table: "Promotions");

            migrationBuilder.DropIndex(
                name: "IX_Genres_NormalizedName",
                table: "Genres");

            migrationBuilder.DropColumn(
                name: "NormalizedName",
                table: "Promotions");

            migrationBuilder.DropColumn(
                name: "NormalizedName",
                table: "Genres");

            migrationBuilder.AddForeignKey(
                name: "FK_MovieGenres_Genres_GenreId",
                table: "MovieGenres",
                column: "GenreId",
                principalTable: "Genres",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
