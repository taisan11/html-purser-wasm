const std = @import("std");
const Node = @import("node.zig").Node;
const Selector = @import("selector.zig").Selector;

pub fn querySelector(allocator: std.mem.Allocator, root: *Node, selector_str: []const u8) !?*Node {
    const selector = try Selector.parse(allocator, selector_str);
    return querySelectNode(root, selector);
}

pub fn querySelectorAll(allocator: std.mem.Allocator, root: *Node, selector_str: []const u8) !std.ArrayList(*Node) {
    const selector = try Selector.parse(allocator, selector_str);
    var results: std.ArrayList(*Node) = .empty;
    try collectMatchingNodes(allocator, root, selector, &results);
    return results;
}

pub fn querySelectorAllText(allocator: std.mem.Allocator, root: *Node, selector_str: []const u8) !std.ArrayList([]const u8) {
    var nodes = try querySelectorAll(allocator, root, selector_str);
    defer nodes.deinit(allocator);
    
    var results: std.ArrayList([]const u8) = .empty;
    for (nodes.items) |node| {
        const text = try node.getTextContent(allocator);
        try results.append(allocator, text);
    }
    return results;
}

pub fn querySelectorAttribute(allocator: std.mem.Allocator, root: *Node, selector_str: []const u8, attr_name: []const u8) !std.ArrayList([]const u8) {
    var nodes = try querySelectorAll(allocator, root, selector_str);
    defer nodes.deinit(allocator);
    
    var results: std.ArrayList([]const u8) = .empty;
    for (nodes.items) |node| {
        if (node.getAttribute(attr_name)) |attr_value| {
            try results.append(allocator, attr_value);
        }
    }
    return results;
}

fn querySelectNode(node: *Node, selector: Selector) ?*Node {
    if (selector.matches(node)) {
        return node;
    }
    
    for (node.children.items) |child| {
        if (querySelectNode(child, selector)) |found| {
            return found;
        }
    }
    
    return null;
}

fn collectMatchingNodes(allocator: std.mem.Allocator, node: *Node, selector: Selector, results: *std.ArrayList(*Node)) !void {
    if (selector.matches(node)) {
        try results.append(allocator, node);
    }
    
    for (node.children.items) |child| {
        try collectMatchingNodes(allocator, child, selector, results);
    }
}

test "querySelector single element" {
    const allocator = std.testing.allocator;
    
    const doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }
    
    const div = try Node.createElement(allocator, "div");
    try div.setAttribute("class", "container");
    try doc.appendChild(div);
    
    const p = try Node.createElement(allocator, "p");
    try p.setAttribute("id", "main");
    try div.appendChild(p);
    
    const result = try querySelector(allocator, doc, ".container");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("div", result.?.tag_name.?);
    
    const result2 = try querySelector(allocator, doc, "#main");
    try std.testing.expect(result2 != null);
    try std.testing.expectEqualStrings("p", result2.?.tag_name.?);
}

test "querySelectorAll multiple elements" {
    const allocator = std.testing.allocator;
    
    const doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }
    
    const div = try Node.createElement(allocator, "div");
    try doc.appendChild(div);
    
    const p1 = try Node.createElement(allocator, "p");
    try p1.setAttribute("class", "text");
    try div.appendChild(p1);
    
    const p2 = try Node.createElement(allocator, "p");
    try p2.setAttribute("class", "text");
    try div.appendChild(p2);
    
    const p3 = try Node.createElement(allocator, "p");
    try div.appendChild(p3);
    
    var results = try querySelectorAll(allocator, doc, ".text");
    defer results.deinit(allocator);
    
    try std.testing.expect(results.items.len == 2);
}

test "querySelectorAllText" {
    const allocator = std.testing.allocator;
    
    const doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }
    
    const div = try Node.createElement(allocator, "div");
    try doc.appendChild(div);
    
    const p1 = try Node.createElement(allocator, "p");
    try p1.setAttribute("class", "item");
    try div.appendChild(p1);
    const text1 = try Node.createText(allocator, "Hello");
    try p1.appendChild(text1);
    
    const p2 = try Node.createElement(allocator, "p");
    try p2.setAttribute("class", "item");
    try div.appendChild(p2);
    const text2 = try Node.createText(allocator, "World");
    try p2.appendChild(text2);
    
    var results = try querySelectorAllText(allocator, doc, ".item");
    defer {
        for (results.items) |text| {
            allocator.free(text);
        }
        results.deinit(allocator);
    }
    
    try std.testing.expect(results.items.len == 2);
    try std.testing.expectEqualStrings("Hello", std.mem.trim(u8, results.items[0], " "));
    try std.testing.expectEqualStrings("World", std.mem.trim(u8, results.items[1], " "));
}

test "querySelectorAttribute" {
    const allocator = std.testing.allocator;
    
    const doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }
    
    const div = try Node.createElement(allocator, "div");
    try doc.appendChild(div);
    
    const a1 = try Node.createElement(allocator, "a");
    try a1.setAttribute("href", "https://example.com");
    try div.appendChild(a1);
    
    const a2 = try Node.createElement(allocator, "a");
    try a2.setAttribute("href", "https://test.com");
    try div.appendChild(a2);
    
    var results = try querySelectorAttribute(allocator, doc, "a", "href");
    defer results.deinit(allocator);
    
    try std.testing.expect(results.items.len == 2);
    try std.testing.expectEqualStrings("https://example.com", results.items[0]);
    try std.testing.expectEqualStrings("https://test.com", results.items[1]);
}
