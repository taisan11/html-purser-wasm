const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const TokenType = @import("tokenizer.zig").TokenType;
const Node = @import("node.zig").Node;
const Selector = @import("selector.zig").Selector;

pub const MatchResult = struct {
    text: []const u8,
    attributes: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MatchResult) void {
        self.allocator.free(self.text);
        self.attributes.deinit();
    }
};

pub const StreamingParser = struct {
    buffer: std.ArrayList(u8),
    selectors: std.ArrayList(Selector),
    matches: std.StringHashMap(std.ArrayList(MatchResult)),
    
    current_element: ?Element = null,
    element_stack: std.ArrayList(Element),
    depth: usize = 0,
    
    allocator: std.mem.Allocator,

    const Element = struct {
        tag_name: []const u8,
        attributes: std.StringHashMap([]const u8),
        text_buffer: std.ArrayList(u8),
        depth: usize,
        matched: bool,
        selector_index: ?usize,
    };

    const SelfClosingTags = [_][]const u8{
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    };

    pub fn init(allocator: std.mem.Allocator) StreamingParser {
        return .{
            .buffer = .empty,
            .selectors = .empty,
            .matches = std.StringHashMap(std.ArrayList(MatchResult)).init(allocator),
            .element_stack = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StreamingParser) void {
        self.buffer.deinit(self.allocator);
        self.selectors.deinit(self.allocator);
        
        var iter = self.matches.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |*match| {
                match.deinit();
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.matches.deinit();
        
        for (self.element_stack.items) |*elem| {
            elem.attributes.deinit();
            elem.text_buffer.deinit(self.allocator);
        }
        self.element_stack.deinit(self.allocator);
        
        if (self.current_element) |cur_elem| {
            var elem = cur_elem;
            elem.attributes.deinit();
            elem.text_buffer.deinit(self.allocator);
        }
    }

    pub fn addSelector(self: *StreamingParser, selector_str: []const u8) !void {
        const selector = try Selector.parse(self.allocator, selector_str);
        try self.selectors.append(self.allocator, selector);
        
        const key = try self.allocator.dupe(u8, selector_str);
        const list: std.ArrayList(MatchResult) = .empty;
        try self.matches.put(key, list);
    }

    pub fn feed(self: *StreamingParser, chunk: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, chunk);
        try self.processBuffer();
    }

    pub fn finish(self: *StreamingParser) !void {
        try self.processBuffer();
        
        if (self.current_element) |cur_elem| {
            var mut_elem = cur_elem;
            try self.finalizeElement(&mut_elem);
            self.current_element = null;
        }
        
        while (self.element_stack.items.len > 0) {
            const last_idx = self.element_stack.items.len - 1;
            var elem = self.element_stack.items[last_idx];
            _ = self.element_stack.orderedRemove(last_idx);
            try self.finalizeElement(&elem);
        }
    }

    fn processBuffer(self: *StreamingParser) !void {
        const html = self.buffer.items;
        var tokenizer = Tokenizer.init(self.allocator, html);
        
        var last_pos: usize = 0;
        
        while (true) {
            const start_pos = tokenizer.pos;
            var token = tokenizer.next() catch |err| {
                if (err == error.OutOfMemory) return err;
                last_pos = start_pos;
                break;
            } orelse {
                last_pos = tokenizer.pos;
                break;
            };
            defer token.deinit();
            
            if (token.type == .eof) {
                last_pos = tokenizer.pos;
                break;
            }
            
            const is_complete = tokenizer.pos < html.len or token.type != .start_tag;
            if (!is_complete) {
                last_pos = start_pos;
                break;
            }
            
            try self.processToken(&token);
            last_pos = tokenizer.pos;
        }
        
        if (last_pos > 0) {
            const remaining = html[last_pos..];
            var new_buffer: std.ArrayList(u8) = .empty;
            try new_buffer.appendSlice(self.allocator, remaining);
            self.buffer.deinit(self.allocator);
            self.buffer = new_buffer;
        }
    }

    fn processToken(self: *StreamingParser, token: *Token) !void {
        switch (token.type) {
            .start_tag => {
                if (self.current_element) |*elem| {
                    try self.element_stack.append(self.allocator, elem.*);
                    self.current_element = null;
                }
                
                var new_elem = Element{
                    .tag_name = token.data,
                    .attributes = std.StringHashMap([]const u8).init(self.allocator),
                    .text_buffer = .empty,
                    .depth = self.depth,
                    .matched = false,
                    .selector_index = null,
                };
                
                var attr_iter = token.attributes.iterator();
                while (attr_iter.next()) |entry| {
                    try new_elem.attributes.put(entry.key_ptr.*, entry.value_ptr.*);
                }
                
                for (self.selectors.items, 0..) |selector, i| {
                    if (self.matchesSelector(&new_elem, selector)) {
                        new_elem.matched = true;
                        new_elem.selector_index = i;
                        break;
                    }
                }
                
                if (isSelfClosing(token.data)) {
                    if (new_elem.matched) {
                        try self.finalizeElement(&new_elem);
                    } else {
                        new_elem.attributes.deinit();
                        new_elem.text_buffer.deinit(self.allocator);
                    }
                } else {
                    self.current_element = new_elem;
                    self.depth += 1;
                }
            },
            .end_tag => {
                if (self.current_element) |*elem| {
                    if (std.mem.eql(u8, elem.tag_name, token.data)) {
                        try self.finalizeElement(elem);
                        self.current_element = null;
                        self.depth -= 1;
                        return;
                    }
                }
                
                var i: usize = self.element_stack.items.len;
                while (i > 0) {
                    i -= 1;
                    if (std.mem.eql(u8, self.element_stack.items[i].tag_name, token.data)) {
                        var elem = self.element_stack.orderedRemove(i);
                        try self.finalizeElement(&elem);
                        self.depth -= 1;
                        break;
                    }
                }
            },
            .text => {
                if (self.current_element) |*elem| {
                    if (elem.matched) {
                        const trimmed = std.mem.trim(u8, token.data, " \t\n\r");
                        if (trimmed.len > 0) {
                            if (elem.text_buffer.items.len > 0) {
                                try elem.text_buffer.append(self.allocator, ' ');
                            }
                            try elem.text_buffer.appendSlice(self.allocator, trimmed);
                        }
                    }
                }
            },
            .comment, .doctype, .eof => {},
        }
    }

    fn matchesSelector(self: *StreamingParser, elem: *const Element, selector: Selector) bool {
        _ = self;
        
        switch (selector.type) {
            .universal => return true,
            .tag => {
                return std.ascii.eqlIgnoreCase(elem.tag_name, selector.value);
            },
            .class => {
                if (elem.attributes.get("class")) |class_value| {
                    var iter = std.mem.tokenizeAny(u8, class_value, " \t\n\r");
                    while (iter.next()) |class_name| {
                        if (std.mem.eql(u8, class_name, selector.value)) {
                            return true;
                        }
                    }
                }
                return false;
            },
            .id => {
                if (elem.attributes.get("id")) |id_value| {
                    return std.mem.eql(u8, id_value, selector.value);
                }
                return false;
            },
            .attribute => {
                if (selector.attr_name) |attr_name| {
                    if (elem.attributes.get(attr_name)) |attr_value| {
                        if (selector.value.len == 0) {
                            return true;
                        }
                        return std.mem.eql(u8, attr_value, selector.value);
                    }
                }
                return false;
            },
        }
    }

    fn finalizeElement(self: *StreamingParser, elem: *Element) !void {
        defer {
            elem.attributes.deinit();
            elem.text_buffer.deinit(self.allocator);
        }
        
        if (!elem.matched) return;
        
        const selector_index = elem.selector_index orelse return;
        const selector = self.selectors.items[selector_index];
        
        const selector_key = switch (selector.type) {
            .tag => selector.value,
            .class => blk: {
                var buf: [256]u8 = undefined;
                const key = std.fmt.bufPrint(&buf, ".{s}", .{selector.value}) catch return;
                break :blk key;
            },
            .id => blk: {
                var buf: [256]u8 = undefined;
                const key = std.fmt.bufPrint(&buf, "#{s}", .{selector.value}) catch return;
                break :blk key;
            },
            .attribute => blk: {
                if (selector.attr_name) |attr_name| {
                    var buf: [256]u8 = undefined;
                    const key = if (selector.value.len > 0)
                        std.fmt.bufPrint(&buf, "[{s}={s}]", .{ attr_name, selector.value }) catch return
                    else
                        std.fmt.bufPrint(&buf, "[{s}]", .{attr_name}) catch return;
                    break :blk key;
                } else {
                    return;
                }
            },
            .universal => "*",
        };
        
        var matches_list = self.matches.getPtr(selector_key) orelse return;
        
        const text = try elem.text_buffer.toOwnedSlice(self.allocator);
        
        var attrs = std.StringHashMap([]const u8).init(self.allocator);
        var attr_iter = elem.attributes.iterator();
        while (attr_iter.next()) |entry| {
            try attrs.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        
        try matches_list.append(self.allocator, .{
            .text = text,
            .attributes = attrs,
            .allocator = self.allocator,
        });
    }

    pub fn getMatches(self: *StreamingParser, selector: []const u8) ?[]const MatchResult {
        if (self.matches.get(selector)) |list| {
            return list.items;
        }
        return null;
    }

    fn isSelfClosing(tag_name: []const u8) bool {
        for (SelfClosingTags) |tag| {
            if (std.ascii.eqlIgnoreCase(tag, tag_name)) {
                return true;
            }
        }
        return false;
    }
};

test "streaming parser basic" {
    const allocator = std.testing.allocator;
    
    var parser = StreamingParser.init(allocator);
    defer parser.deinit();
    
    try parser.addSelector(".price");
    try parser.addSelector("#title");
    
    const html1 = "<div><h1 id=\"title\">Test";
    const html2 = " Title</h1><span class=\"price\">$99</span></div>";
    
    try parser.feed(html1);
    try parser.feed(html2);
    try parser.finish();
    
    const titles = parser.getMatches("#title").?;
    try std.testing.expect(titles.len == 1);
    try std.testing.expectEqualStrings("Test Title", titles[0].text);
    
    const prices = parser.getMatches(".price").?;
    try std.testing.expect(prices.len == 1);
    try std.testing.expectEqualStrings("$99", prices[0].text);
}

test "streaming parser multiple matches" {
    const allocator = std.testing.allocator;
    
    var parser = StreamingParser.init(allocator);
    defer parser.deinit();
    
    try parser.addSelector(".item");
    
    try parser.feed("<ul><li class=\"item\">Item 1</li>");
    try parser.feed("<li class=\"item\">Item 2</li>");
    try parser.feed("<li class=\"item\">Item 3</li></ul>");
    try parser.finish();
    
    const items = parser.getMatches(".item").?;
    try std.testing.expect(items.len == 3);
    try std.testing.expectEqualStrings("Item 1", items[0].text);
    try std.testing.expectEqualStrings("Item 2", items[1].text);
    try std.testing.expectEqualStrings("Item 3", items[2].text);
}
