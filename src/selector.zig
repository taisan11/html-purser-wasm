const std = @import("std");
const Node = @import("node.zig").Node;

pub const SelectorType = enum {
    tag,
    class,
    id,
    attribute,
    universal,
};

pub const Selector = struct {
    type: SelectorType,
    value: []const u8,
    attr_name: ?[]const u8,

    pub fn parse(allocator: std.mem.Allocator, selector: []const u8) !Selector {
        _ = allocator;
        
        const trimmed = std.mem.trim(u8, selector, " \t\n\r");
        
        if (trimmed.len == 0) {
            return error.EmptySelector;
        }

        // Universal selector *
        if (std.mem.eql(u8, trimmed, "*")) {
            return Selector{
                .type = .universal,
                .value = "",
                .attr_name = null,
            };
        }

        // ID selector #id
        if (trimmed[0] == '#') {
            if (trimmed.len == 1) return error.InvalidSelector;
            return Selector{
                .type = .id,
                .value = trimmed[1..],
                .attr_name = null,
            };
        }

        // Class selector .class
        if (trimmed[0] == '.') {
            if (trimmed.len == 1) return error.InvalidSelector;
            return Selector{
                .type = .class,
                .value = trimmed[1..],
                .attr_name = null,
            };
        }

        // Attribute selector [attr] or [attr=value]
        if (trimmed[0] == '[') {
            const close_idx = std.mem.indexOf(u8, trimmed, "]") orelse return error.InvalidSelector;
            const attr_content = trimmed[1..close_idx];
            
            if (std.mem.indexOf(u8, attr_content, "=")) |eq_idx| {
                const attr_name = std.mem.trim(u8, attr_content[0..eq_idx], " \t");
                var attr_value = std.mem.trim(u8, attr_content[eq_idx + 1..], " \t");
                
                // Remove quotes
                if (attr_value.len >= 2) {
                    if ((attr_value[0] == '"' and attr_value[attr_value.len - 1] == '"') or
                        (attr_value[0] == '\'' and attr_value[attr_value.len - 1] == '\''))
                    {
                        attr_value = attr_value[1 .. attr_value.len - 1];
                    }
                }
                
                return Selector{
                    .type = .attribute,
                    .value = attr_value,
                    .attr_name = attr_name,
                };
            } else {
                return Selector{
                    .type = .attribute,
                    .value = "",
                    .attr_name = std.mem.trim(u8, attr_content, " \t"),
                };
            }
        }

        // Tag selector
        return Selector{
            .type = .tag,
            .value = trimmed,
            .attr_name = null,
        };
    }

    pub fn matches(self: Selector, node: *Node) bool {
        if (node.type != .element) return false;

        switch (self.type) {
            .universal => return true,
            .tag => {
                if (node.tag_name) |tag| {
                    return std.ascii.eqlIgnoreCase(tag, self.value);
                }
                return false;
            },
            .class => {
                if (node.getAttribute("class")) |class_value| {
                    var iter = std.mem.tokenizeAny(u8, class_value, " \t\n\r");
                    while (iter.next()) |class_name| {
                        if (std.mem.eql(u8, class_name, self.value)) {
                            return true;
                        }
                    }
                }
                return false;
            },
            .id => {
                if (node.getAttribute("id")) |id_value| {
                    return std.mem.eql(u8, id_value, self.value);
                }
                return false;
            },
            .attribute => {
                if (self.attr_name) |attr_name| {
                    if (node.getAttribute(attr_name)) |attr_value| {
                        if (self.value.len == 0) {
                            return true;
                        }
                        return std.mem.eql(u8, attr_value, self.value);
                    }
                }
                return false;
            },
        }
    }
};

test "selector parse tag" {
    const allocator = std.testing.allocator;
    const selector = try Selector.parse(allocator, "div");
    try std.testing.expect(selector.type == .tag);
    try std.testing.expectEqualStrings("div", selector.value);
}

test "selector parse class" {
    const allocator = std.testing.allocator;
    const selector = try Selector.parse(allocator, ".container");
    try std.testing.expect(selector.type == .class);
    try std.testing.expectEqualStrings("container", selector.value);
}

test "selector parse id" {
    const allocator = std.testing.allocator;
    const selector = try Selector.parse(allocator, "#main");
    try std.testing.expect(selector.type == .id);
    try std.testing.expectEqualStrings("main", selector.value);
}

test "selector parse attribute" {
    const allocator = std.testing.allocator;
    
    const sel1 = try Selector.parse(allocator, "[href]");
    try std.testing.expect(sel1.type == .attribute);
    try std.testing.expectEqualStrings("href", sel1.attr_name.?);
    try std.testing.expectEqualStrings("", sel1.value);
    
    const sel2 = try Selector.parse(allocator, "[type=\"text\"]");
    try std.testing.expect(sel2.type == .attribute);
    try std.testing.expectEqualStrings("type", sel2.attr_name.?);
    try std.testing.expectEqualStrings("text", sel2.value);
}

test "selector matches" {
    const allocator = std.testing.allocator;
    
    const div = try Node.createElement(allocator, "div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    try div.setAttribute("class", "container main");
    try div.setAttribute("id", "content");
    
    const tag_sel = try Selector.parse(allocator, "div");
    try std.testing.expect(tag_sel.matches(div));
    
    const class_sel = try Selector.parse(allocator, ".container");
    try std.testing.expect(class_sel.matches(div));
    
    const id_sel = try Selector.parse(allocator, "#content");
    try std.testing.expect(id_sel.matches(div));
    
    const wrong_sel = try Selector.parse(allocator, "span");
    try std.testing.expect(!wrong_sel.matches(div));
}
