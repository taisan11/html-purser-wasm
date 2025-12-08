const std = @import("std");

pub const NodeType = enum {
    element,
    text,
    comment,
    document,
};

pub const Node = struct {
    type: NodeType,
    tag_name: ?[]const u8,
    text_content: ?[]const u8,
    attributes: std.StringHashMap([]const u8),
    children: std.ArrayList(*Node),
    parent: ?*Node,
    allocator: std.mem.Allocator,

    pub fn createDocument(allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = .document,
            .tag_name = null,
            .text_content = null,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .children = .empty,
            .parent = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn createElement(allocator: std.mem.Allocator, tag_name: []const u8) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = .element,
            .tag_name = tag_name,
            .text_content = null,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .children = .empty,
            .parent = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn createText(allocator: std.mem.Allocator, text: []const u8) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = .text,
            .tag_name = null,
            .text_content = text,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .children = .empty,
            .parent = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn createComment(allocator: std.mem.Allocator, text: []const u8) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = .comment,
            .tag_name = null,
            .text_content = text,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .children = .empty,
            .parent = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn appendChild(self: *Node, child: *Node) !void {
        child.parent = self;
        try self.children.append(self.allocator, child);
    }

    pub fn setAttribute(self: *Node, name: []const u8, value: []const u8) !void {
        try self.attributes.put(name, value);
    }

    pub fn getAttribute(self: *Node, name: []const u8) ?[]const u8 {
        return self.attributes.get(name);
    }

    pub fn deinit(self: *Node) void {
        self.attributes.deinit();
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn getTextContent(self: *Node, allocator: std.mem.Allocator) ![]const u8 {
        var list: std.ArrayList(u8) = .empty;
        try self.collectText(allocator, &list);
        return try list.toOwnedSlice(allocator);
    }

    fn collectText(self: *Node, allocator: std.mem.Allocator, list: *std.ArrayList(u8)) !void {
        switch (self.type) {
            .text => {
                if (self.text_content) |text| {
                    const trimmed = std.mem.trim(u8, text, " \t\n\r");
                    if (trimmed.len > 0) {
                        if (list.items.len > 0 and list.items[list.items.len - 1] != ' ') {
                            try list.append(allocator, ' ');
                        }
                        try list.appendSlice(allocator, trimmed);
                    }
                }
            },
            .element, .document => {
                for (self.children.items) |child| {
                    try child.collectText(allocator, list);
                }
            },
            .comment => {},
        }
    }
};

test "node creation" {
    const allocator = std.testing.allocator;

    var doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }

    var div = try Node.createElement(allocator, "div");
    try div.setAttribute("class", "test");
    try doc.appendChild(div);

    const text = try Node.createText(allocator, "Hello");
    try div.appendChild(text);

    try std.testing.expect(doc.children.items.len == 1);
    try std.testing.expectEqualStrings("div", div.tag_name.?);
    try std.testing.expectEqualStrings("test", div.getAttribute("class").?);
}

test "get text content" {
    const allocator = std.testing.allocator;

    var doc = try Node.createDocument(allocator);
    defer {
        doc.deinit();
        allocator.destroy(doc);
    }

    var div = try Node.createElement(allocator, "div");
    try doc.appendChild(div);

    const text1 = try Node.createText(allocator, "Hello ");
    try div.appendChild(text1);

    var span = try Node.createElement(allocator, "span");
    try div.appendChild(span);

    const text2 = try Node.createText(allocator, "World");
    try span.appendChild(text2);

    const content = try doc.getTextContent(allocator);
    defer allocator.free(content);

    try std.testing.expectEqualStrings("Hello World", content);
}
