const std = @import("std");
const StreamingParser = @import("streaming.zig").StreamingParser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== Streaming HTML Parser Demo ===\n\n", .{});

    // シミュレート: 大きなHTMLをチャンクで処理
    const chunks = [_][]const u8{
        "<!DOCTYPE html><html><body>",
        "<div class=\"product\">",
        "  <h2 class=\"title\">Product 1</h2>",
        "  <span class=\"price\">$99.99</span>",
        "  <p class=\"description\">Great product!</p>",
        "</div>",
        "<div class=\"product\">",
        "  <h2 class=\"title\">Product 2</h2>",
        "  <span class=\"price\">$149.99</span>",
        "  <p class=\"description\">Amazing quality!</p>",
        "</div>",
        "<div class=\"product\">",
        "  <h2 class=\"title\">Product 3</h2>",
        "  <span class=\"price\">$199.99</span>",
        "  <p class=\"description\">Best seller!</p>",
        "</div>",
        "</body></html>",
    };

    var parser = StreamingParser.init(allocator);
    defer parser.deinit();

    // セレクターを登録
    try parser.addSelector(".title");
    try parser.addSelector(".price");
    try parser.addSelector(".description");

    std.debug.print("Processing chunks...\n", .{});

    // チャンクごとに処理
    for (chunks, 0..) |chunk, i| {
        std.debug.print("  Chunk {d}: {d} bytes\n", .{ i + 1, chunk.len });
        try parser.feed(chunk);
    }

    // 処理を完了
    try parser.finish();

    std.debug.print("\nResults:\n", .{});

    // タイトルを取得
    if (parser.getMatches(".title")) |titles| {
        std.debug.print("\nTitles:\n", .{});
        for (titles, 0..) |title, i| {
            std.debug.print("  {d}. {s}\n", .{ i + 1, std.mem.trim(u8, title.text, " ") });
        }
    }

    // 価格を取得
    if (parser.getMatches(".price")) |prices| {
        std.debug.print("\nPrices:\n", .{});
        for (prices, 0..) |price, i| {
            std.debug.print("  {d}. {s}\n", .{ i + 1, std.mem.trim(u8, price.text, " ") });
        }
    }

    // 説明を取得
    if (parser.getMatches(".description")) |descriptions| {
        std.debug.print("\nDescriptions:\n", .{});
        for (descriptions, 0..) |desc, i| {
            std.debug.print("  {d}. {s}\n", .{ i + 1, std.mem.trim(u8, desc.text, " ") });
        }
    }

    std.debug.print("\n✅ Streaming parse completed successfully!\n", .{});
    std.debug.print("   Memory efficient: Only matched elements kept in memory\n", .{});
}
