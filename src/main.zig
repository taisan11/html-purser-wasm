const std = @import("std");
const html_purser_wasm = @import("html_purser_wasm");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Test Page</title>
        \\</head>
        \\<body>
        \\    <div class="container">
        \\        <h1 id="main-title">HTML Parser Demo</h1>
        \\        <p class="intro">This is a <strong>test</strong> paragraph.</p>
        \\        <ul class="items">
        \\            <li class="item">Item 1</li>
        \\            <li class="item">Item 2</li>
        \\            <li class="item">Item 3</li>
        \\        </ul>
        \\        <a href="https://example.com">Example Link</a>
        \\        <a href="https://test.com">Test Link</a>
        \\    </div>
        \\</body>
        \\</html>
    ;

    var parser = try html_purser_wasm.Parser.init(allocator, html);
    defer parser.deinit();

    const doc = try parser.parse();

    std.debug.print("=== HTML Parser with Selector Demo ===\n\n", .{});

    // querySelector - 単一要素取得
    if (try html_purser_wasm.querySelector(allocator, doc, "#main-title")) |title| {
        const text = try title.getTextContent(allocator);
        defer allocator.free(text);
        std.debug.print("Title: {s}\n\n", .{text});
    }

    // querySelectorAll - 複数要素のテキスト取得
    std.debug.print("All items:\n", .{});
    var items = try html_purser_wasm.querySelectorAllText(allocator, doc, ".item");
    defer {
        for (items.items) |text| {
            allocator.free(text);
        }
        items.deinit(allocator);
    }
    for (items.items, 0..) |text, i| {
        std.debug.print("  {d}. {s}\n", .{ i + 1, std.mem.trim(u8, text, " ") });
    }

    // 属性の一括取得
    std.debug.print("\nAll links:\n", .{});
    var links = try html_purser_wasm.querySelectorAttribute(allocator, doc, "a", "href");
    defer links.deinit(allocator);
    for (links.items) |href| {
        std.debug.print("  - {s}\n", .{href});
    }

    // タグセレクター
    std.debug.print("\nAll paragraphs:\n", .{});
    var paragraphs = try html_purser_wasm.querySelectorAllText(allocator, doc, "p");
    defer {
        for (paragraphs.items) |text| {
            allocator.free(text);
        }
        paragraphs.deinit(allocator);
    }
    for (paragraphs.items) |text| {
        std.debug.print("  {s}\n", .{std.mem.trim(u8, text, " ")});
    }

    // クラスセレクター
    std.debug.print("\nContainer content:\n", .{});
    if (try html_purser_wasm.querySelector(allocator, doc, ".container")) |container| {
        const text = try container.getTextContent(allocator);
        defer allocator.free(text);
        std.debug.print("  {s}\n", .{std.mem.trim(u8, text, " ")});
    }
}
