using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace OnlineCinema.Domain.Migrations
{
    /// <inheritdoc />
    public partial class UniqueNormalizedPhone : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "NormalizedPhoneNumber",
                table: "AspNetUsers",
                type: "text",
                nullable: true,
                computedColumnSql: "CASE\n    WHEN \"PhoneNumber\" IS NULL OR \"PhoneNumber\" ~ '[^0-9+ ()-]' THEN NULL\n    WHEN length(regexp_replace(\"PhoneNumber\", '[^0-9]', '', 'g')) = 10\n        THEN '+7' || regexp_replace(\"PhoneNumber\", '[^0-9]', '', 'g')\n    WHEN length(regexp_replace(\"PhoneNumber\", '[^0-9]', '', 'g')) = 11\n        AND left(regexp_replace(\"PhoneNumber\", '[^0-9]', '', 'g'), 1) IN ('7', '8')\n        THEN '+7' || substring(regexp_replace(\"PhoneNumber\", '[^0-9]', '', 'g') from 2)\n    ELSE NULL\nEND",
                stored: true);

            migrationBuilder.Sql("""
                DO $$ BEGIN
                    IF EXISTS (SELECT "NormalizedPhoneNumber" FROM "AspNetUsers"
                        WHERE "NormalizedPhoneNumber" IS NOT NULL
                        GROUP BY "NormalizedPhoneNumber" HAVING count(*) > 1) THEN
                        RAISE EXCEPTION 'Обнаружены повторные нормализованные телефоны. Миграция отменена; разрешите конфликт без удаления пользователей.';
                    END IF;
                END $$;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUsers_NormalizedPhoneNumber",
                table: "AspNetUsers",
                column: "NormalizedPhoneNumber",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AspNetUsers_NormalizedPhoneNumber",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "NormalizedPhoneNumber",
                table: "AspNetUsers");
        }
    }
}
