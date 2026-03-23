using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace DoAnQuanLyQuanAnAI.Migrations
{
    /// <inheritdoc />
    public partial class UpdateSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Invoices_InvoiceNo",
                table: "Invoices");

            migrationBuilder.DropIndex(
                name: "IX_Invoices_PaidAt",
                table: "Invoices");

            migrationBuilder.DropIndex(
                name: "IX_ActionLogs_AccountId_Timestamp",
                table: "ActionLogs");

            migrationBuilder.DropIndex(
                name: "IX_ActionLogs_IsFlagged",
                table: "ActionLogs");

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 10);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "DiningTables",
                keyColumn: "TableId",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 10);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 13);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 15);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 17);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 18);

            migrationBuilder.DeleteData(
                table: "MenuItems",
                keyColumn: "ItemId",
                keyValue: 19);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "MenuCategories",
                keyColumn: "CategoryId",
                keyValue: 6);

            migrationBuilder.CreateIndex(
                name: "IX_ActionLogs_AccountId",
                table: "ActionLogs",
                column: "AccountId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ActionLogs_AccountId",
                table: "ActionLogs");

            migrationBuilder.InsertData(
                table: "DiningTables",
                columns: new[] { "TableId", "Capacity", "IsActive", "Status", "TableName" },
                values: new object[,]
                {
                    { 1, 4, true, 0, "Bàn 1" },
                    { 2, 4, true, 0, "Bàn 2" },
                    { 3, 6, true, 0, "Bàn 3" },
                    { 4, 4, true, 0, "Bàn 4" },
                    { 5, 4, true, 0, "Bàn 5" },
                    { 6, 8, true, 0, "Bàn 6" },
                    { 7, 4, true, 0, "Bàn 7" },
                    { 8, 4, true, 0, "Bàn 8" },
                    { 9, 6, true, 0, "Bàn 9" },
                    { 10, 4, true, 0, "Bàn 10" },
                    { 11, 10, true, 0, "Bàn VIP 1" },
                    { 12, 10, true, 0, "Bàn VIP 2" }
                });

            migrationBuilder.InsertData(
                table: "MenuCategories",
                columns: new[] { "CategoryId", "DisplayOrder", "Icon", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, 1, "🥗", true, "Khai Vị" },
                    { 2, 2, "🍖", true, "Món Chính" },
                    { 3, 3, "🍚", true, "Cơm - Cháo" },
                    { 4, 4, "🍲", true, "Lẩu" },
                    { 5, 5, "🥤", true, "Đồ Uống" },
                    { 6, 6, "🍮", true, "Tráng Miệng" }
                });

            migrationBuilder.InsertData(
                table: "MenuItems",
                columns: new[] { "ItemId", "CategoryId", "CreatedAt", "Description", "Emoji", "ImagePath", "IsAvailable", "Name", "Price" },
                values: new object[,]
                {
                    { 1, 1, new DateTime(2026, 3, 5, 23, 38, 0, 980, DateTimeKind.Local).AddTicks(8506), null, "🥗", null, true, "Gỏi cuốn tôm thịt", 45000m },
                    { 2, 1, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6719), null, "🌮", null, true, "Chả giò chiên giòn", 55000m },
                    { 3, 1, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6737), null, "🥣", null, true, "Súp cua bắp non", 65000m },
                    { 4, 2, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6739), null, "🥩", null, true, "Bò lúc lắc sốt tiêu", 185000m },
                    { 5, 2, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6740), null, "🐟", null, true, "Cá lóc nướng trui", 220000m },
                    { 6, 2, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6742), null, "🍗", null, true, "Gà chiên mắm tỏi", 165000m },
                    { 7, 2, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6743), null, "🦐", null, true, "Tôm rang muối ớt", 195000m },
                    { 8, 2, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6744), null, "🍖", null, true, "Sườn nướng BBQ", 175000m },
                    { 9, 3, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6746), null, "🍚", null, true, "Cơm chiên dương châu", 75000m },
                    { 10, 3, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6747), null, "🥣", null, true, "Cháo gà hạt sen", 65000m },
                    { 11, 3, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6748), null, "🍛", null, true, "Cơm tấm sườn bì", 85000m },
                    { 12, 4, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6749), null, "🍲", null, true, "Lẩu thái hải sản", 350000m },
                    { 13, 4, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6750), null, "🫕", null, true, "Lẩu bò nhúng dấm", 320000m },
                    { 14, 5, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6752), null, "🍋", null, true, "Nước chanh tươi", 30000m },
                    { 15, 5, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6753), null, "🥭", null, true, "Sinh tố xoài", 45000m },
                    { 16, 5, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6754), null, "🍺", null, true, "Bia Tiger (lon)", 35000m },
                    { 17, 5, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6755), null, "🥤", null, true, "Nước ngọt Pepsi", 25000m },
                    { 18, 6, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6756), null, "🍮", null, true, "Chè bưởi trân châu", 45000m },
                    { 19, 6, new DateTime(2026, 3, 5, 23, 38, 0, 982, DateTimeKind.Local).AddTicks(6757), null, "🍨", null, true, "Kem dừa xoài", 55000m }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_InvoiceNo",
                table: "Invoices",
                column: "InvoiceNo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_PaidAt",
                table: "Invoices",
                column: "PaidAt");

            migrationBuilder.CreateIndex(
                name: "IX_ActionLogs_AccountId_Timestamp",
                table: "ActionLogs",
                columns: new[] { "AccountId", "Timestamp" });

            migrationBuilder.CreateIndex(
                name: "IX_ActionLogs_IsFlagged",
                table: "ActionLogs",
                column: "IsFlagged");
        }
    }
}
