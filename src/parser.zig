const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const TokenType = @import("tokenizer.zig").TokenType;
const Node = @import("node.zig").Node;

pub const Parser = struct {
    tokenizer: Tokenizer,
    document: *Node,
    current: *Node,
    allocator: std.mem.Allocator,

    const SelfClosingTags = [_][]const u8{
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    };

    pub fn init(allocator: std.mem.Allocator, html: []const u8) !Parser {
        const document = try Node.createDocument(allocator);
        return Parser{
            .tokenizer = Tokenizer.init(allocator, html),
            .document = document,
            .current = document,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.document.deinit();
        self.allocator.destroy(self.document);
    }

    pub fn parse(self: *Parser) !*Node {
        while (true) {
            var token = try self.tokenizer.next() orelse break;
            defer token.deinit();

            if (token.type == .eof) {
                break;
            }

            try self.processToken(&token);
        }

        return self.document;
    }

    fn processToken(self: *Parser, token: *Token) !void {
        switch (token.type) {
            .start_tag => {
                const element = try Node.createElement(self.allocator, token.data);

                var iter = token.attributes.iterator();
                while (iter.next()) |entry| {
                    try element.setAttribute(entry.key_ptr.*, entry.value_ptr.*);
                }

                try self.current.appendChild(element);

                if (!isSelfClosing(token.data)) {
                    self.current = element;
                }
            },
            .end_tag => {
                if (self.current.parent) |parent| {
                    if (self.current.tag_name) |tag_name| {
                        if (std.mem.eql(u8, tag_name, token.data)) {
                            self.current = parent;
                        } else {
                            var node = self.current;
                            while (node.parent) |p| {
                                if (node.tag_name) |name| {
                                    if (std.mem.eql(u8, name, token.data)) {
                                        self.current = p;
                                        break;
                                    }
                                }
                                node = p;
                            }
                        }
                    }
                }
            },
            .text => {
                const trimmed = std.mem.trim(u8, token.data, " \t\n\r");
                if (trimmed.len > 0) {
                    const text_node = try Node.createText(self.allocator, token.data);
                    try self.current.appendChild(text_node);
                }
            },
            .comment => {
                const comment_node = try Node.createComment(self.allocator, token.data);
                try self.current.appendChild(comment_node);
            },
            .doctype => {},
            .eof => {},
        }
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

test "parser basic" {
    const allocator = std.testing.allocator;
    const html = "<div><p>Hello</p></div>";

    var parser = try Parser.init(allocator, html);
    defer parser.deinit();

    const doc = try parser.parse();

    try std.testing.expect(doc.children.items.len == 1);
    const div = doc.children.items[0];
    try std.testing.expectEqualStrings("div", div.tag_name.?);

    try std.testing.expect(div.children.items.len == 1);
    const p = div.children.items[0];
    try std.testing.expectEqualStrings("p", p.tag_name.?);

    try std.testing.expect(p.children.items.len == 1);
    const text = p.children.items[0];
    try std.testing.expectEqualStrings("Hello", text.text_content.?);
}

test "parser with attributes" {
    const allocator = std.testing.allocator;
    const html = "<div class=\"container\" id=\"main\"><a href=\"test.html\">Link</a></div>";

    var parser = try Parser.init(allocator, html);
    defer parser.deinit();

    const doc = try parser.parse();

    const div = doc.children.items[0];
    try std.testing.expectEqualStrings("container", div.getAttribute("class").?);
    try std.testing.expectEqualStrings("main", div.getAttribute("id").?);

    const a = div.children.items[0];
    try std.testing.expectEqualStrings("test.html", a.getAttribute("href").?);
}

test "parser self closing tags" {
    const allocator = std.testing.allocator;
    const html = "<div><img src=\"test.png\"/><br/><input type=\"text\"/></div>";

    var parser = try Parser.init(allocator, html);
    defer parser.deinit();

    const doc = try parser.parse();

    const div = doc.children.items[0];
    try std.testing.expect(div.children.items.len == 3);

    const img = div.children.items[0];
    try std.testing.expectEqualStrings("img", img.tag_name.?);
    try std.testing.expectEqualStrings("test.png", img.getAttribute("src").?);
}

test "parser nested structure" {
    const allocator = std.testing.allocator;
    const html = "<html><body><div><p>Test</p></div></body></html>";

    var parser = try Parser.init(allocator, html);
    defer parser.deinit();

    const doc = try parser.parse();

    const html_node = doc.children.items[0];
    try std.testing.expectEqualStrings("html", html_node.tag_name.?);

    const body = html_node.children.items[0];
    try std.testing.expectEqualStrings("body", body.tag_name.?);

    const div = body.children.items[0];
    try std.testing.expectEqualStrings("div", div.tag_name.?);

    const p = div.children.items[0];
    try std.testing.expectEqualStrings("p", p.tag_name.?);
}
