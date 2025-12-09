const std = @import("std");
const Node = @import("node.zig").Node;
const Parser = @import("parser.zig").Parser;
const query = @import("query.zig");

const page_size = 64 * 1024; // 64KB
var buffer: [page_size * 16]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();

var parser_instance: ?*Parser = null;
var last_result_nodes: ?std.ArrayList(*Node) = null;
var last_result_texts: ?std.ArrayList([]const u8) = null;
var last_text: ?[]const u8 = null;

// メモリ管理
export fn alloc(size: usize) ?[*]u8 {
    const buf = allocator.alloc(u8, size) catch return null;
    return buf.ptr;
}

export fn dealloc(ptr: [*]u8, size: usize) void {
    const slice = ptr[0..size];
    allocator.free(slice);
}

// HTMLパース
export fn parse(html_ptr: [*]const u8, html_len: usize) bool {
    if (parser_instance) |p| {
        p.deinit();
        allocator.destroy(p);
        parser_instance = null;
    }

    const html = html_ptr[0..html_len];
    
    const parser = allocator.create(Parser) catch return false;
    parser.* = Parser.init(allocator, html) catch {
        allocator.destroy(parser);
        return false;
    };
    
    _ = parser.parse() catch {
        parser.deinit();
        allocator.destroy(parser);
        return false;
    };
    
    parser_instance = parser;
    return true;
}

// クエリ実行（単一要素）
export fn querySelector(selector_ptr: [*]const u8, selector_len: usize) bool {
    const parser = parser_instance orelse return false;
    const doc = parser.document;
    const selector = selector_ptr[0..selector_len];
    
    if (last_text) |text| {
        allocator.free(text);
        last_text = null;
    }
    
    const result = query.querySelector(allocator, doc, selector) catch return false;
    if (result) |node| {
        const text = node.getTextContent(allocator) catch return false;
        last_text = text;
        return true;
    }
    return false;
}

// 最後のqueryResultのテキストを取得
export fn getResultText() ?[*]const u8 {
    if (last_text) |text| {
        return text.ptr;
    }
    return null;
}

export fn getResultTextLen() usize {
    if (last_text) |text| {
        return text.len;
    }
    return 0;
}

// クエリ実行（複数要素）
export fn querySelectorAll(selector_ptr: [*]const u8, selector_len: usize) usize {
    const parser = parser_instance orelse return 0;
    const doc = parser.document;
    const selector = selector_ptr[0..selector_len];
    
    if (last_result_nodes) |*nodes| {
        nodes.deinit(allocator);
        last_result_nodes = null;
    }
    
    const results = query.querySelectorAll(allocator, doc, selector) catch return 0;
    const count = results.items.len;
    last_result_nodes = results;
    return count;
}

// 複数要素のテキストを取得
export fn querySelectorAllText(selector_ptr: [*]const u8, selector_len: usize) usize {
    const parser = parser_instance orelse return 0;
    const doc = parser.document;
    const selector = selector_ptr[0..selector_len];
    
    if (last_result_texts) |*texts| {
        for (texts.items) |text| {
            allocator.free(text);
        }
        texts.deinit(allocator);
        last_result_texts = null;
    }
    
    const results = query.querySelectorAllText(allocator, doc, selector) catch return 0;
    const count = results.items.len;
    last_result_texts = results;
    return count;
}

// インデックスでテキストを取得
export fn getTextAt(index: usize) ?[*]const u8 {
    if (last_result_texts) |texts| {
        if (index < texts.items.len) {
            return texts.items[index].ptr;
        }
    }
    return null;
}

export fn getTextLenAt(index: usize) usize {
    if (last_result_texts) |texts| {
        if (index < texts.items.len) {
            return texts.items[index].len;
        }
    }
    return 0;
}

// 属性値を一括取得
export fn querySelectorAttribute(
    selector_ptr: [*]const u8,
    selector_len: usize,
    attr_ptr: [*]const u8,
    attr_len: usize,
) usize {
    const parser = parser_instance orelse return 0;
    const doc = parser.document;
    const selector = selector_ptr[0..selector_len];
    const attr_name = attr_ptr[0..attr_len];
    
    if (last_result_texts) |*texts| {
        for (texts.items) |text| {
            allocator.free(text);
        }
        texts.deinit(allocator);
        last_result_texts = null;
    }
    
    const results = query.querySelectorAttribute(allocator, doc, selector, attr_name) catch return 0;
    const count = results.items.len;
    last_result_texts = results;
    return count;
}

// クリーンアップ
export fn cleanup() void {
    if (parser_instance) |p| {
        p.deinit();
        allocator.destroy(p);
        parser_instance = null;
    }
    
    if (last_result_nodes) |*nodes| {
        nodes.deinit(allocator);
        last_result_nodes = null;
    }
    
    if (last_result_texts) |*texts| {
        for (texts.items) |text| {
            allocator.free(text);
        }
        texts.deinit(allocator);
        last_result_texts = null;
    }
    
    if (last_text) |text| {
        allocator.free(text);
        last_text = null;
    }
}
