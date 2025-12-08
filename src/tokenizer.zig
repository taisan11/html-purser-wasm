const std = @import("std");

pub const TokenType = enum {
    start_tag,
    end_tag,
    text,
    comment,
    doctype,
    eof,
};

pub const Token = struct {
    type: TokenType,
    data: []const u8,
    attributes: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Token) void {
        self.attributes.deinit();
    }
};

pub const Tokenizer = struct {
    input: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Tokenizer {
        return .{
            .input = input,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn next(self: *Tokenizer) !?Token {
        if (self.pos >= self.input.len) {
            return Token{
                .type = .eof,
                .data = "",
                .attributes = std.StringHashMap([]const u8).init(self.allocator),
                .allocator = self.allocator,
            };
        }

        const c = self.input[self.pos];

        if (c == '<') {
            return try self.readTag();
        } else {
            return try self.readText();
        }
    }

    fn readTag(self: *Tokenizer) !Token {
        const start = self.pos;
        self.pos += 1; // Skip '<'

        if (self.pos >= self.input.len) {
            return self.createTextToken(self.input[start..]);
        }

        // Check for comment
        if (self.pos + 2 < self.input.len and
            self.input[self.pos] == '!' and
            self.input[self.pos + 1] == '-' and
            self.input[self.pos + 2] == '-')
        {
            return try self.readComment();
        }

        // Check for DOCTYPE
        if (self.pos + 6 < self.input.len and
            std.ascii.toLower(self.input[self.pos]) == 'd' and
            std.ascii.toLower(self.input[self.pos + 1]) == 'o' and
            std.ascii.toLower(self.input[self.pos + 2]) == 'c' and
            std.ascii.toLower(self.input[self.pos + 3]) == 't' and
            std.ascii.toLower(self.input[self.pos + 4]) == 'y' and
            std.ascii.toLower(self.input[self.pos + 5]) == 'p' and
            std.ascii.toLower(self.input[self.pos + 6]) == 'e')
        {
            return try self.readDoctype();
        }

        // Check for end tag
        const is_end_tag = self.input[self.pos] == '/';
        if (is_end_tag) {
            self.pos += 1;
        }

        // Skip whitespace
        self.skipWhitespace();

        // Read tag name
        const tag_name_start = self.pos;
        while (self.pos < self.input.len and
            !std.ascii.isWhitespace(self.input[self.pos]) and
            self.input[self.pos] != '>' and
            self.input[self.pos] != '/')
        {
            self.pos += 1;
        }

        if (self.pos == tag_name_start) {
            return self.createTextToken(self.input[start..self.pos]);
        }

        const tag_name = self.input[tag_name_start..self.pos];

        var attributes = std.StringHashMap([]const u8).init(self.allocator);

        if (!is_end_tag) {
            // Read attributes
            while (self.pos < self.input.len and self.input[self.pos] != '>') {
                self.skipWhitespace();

                if (self.pos >= self.input.len or self.input[self.pos] == '>' or self.input[self.pos] == '/') {
                    break;
                }

                const attr = try self.readAttribute();
                if (attr) |a| {
                    try attributes.put(a.name, a.value);
                } else {
                    break;
                }
            }
        }

        // Skip to '>'
        while (self.pos < self.input.len and self.input[self.pos] != '>') {
            self.pos += 1;
        }

        if (self.pos < self.input.len) {
            self.pos += 1; // Skip '>'
        }

        return Token{
            .type = if (is_end_tag) .end_tag else .start_tag,
            .data = tag_name,
            .attributes = attributes,
            .allocator = self.allocator,
        };
    }

    fn readText(self: *Tokenizer) !Token {
        const start = self.pos;
        while (self.pos < self.input.len and self.input[self.pos] != '<') {
            self.pos += 1;
        }
        return self.createTextToken(self.input[start..self.pos]);
    }

    fn readComment(self: *Tokenizer) !Token {
        self.pos += 3; // Skip '!--'
        const start = self.pos;

        while (self.pos + 2 < self.input.len) {
            if (self.input[self.pos] == '-' and
                self.input[self.pos + 1] == '-' and
                self.input[self.pos + 2] == '>')
            {
                const comment_text = self.input[start..self.pos];
                self.pos += 3;
                return Token{
                    .type = .comment,
                    .data = comment_text,
                    .attributes = std.StringHashMap([]const u8).init(self.allocator),
                    .allocator = self.allocator,
                };
            }
            self.pos += 1;
        }

        return self.createTextToken(self.input[start..]);
    }

    fn readDoctype(self: *Tokenizer) !Token {
        const start = self.pos;
        while (self.pos < self.input.len and self.input[self.pos] != '>') {
            self.pos += 1;
        }
        const doctype_text = self.input[start..self.pos];
        if (self.pos < self.input.len) {
            self.pos += 1; // Skip '>'
        }
        return Token{
            .type = .doctype,
            .data = doctype_text,
            .attributes = std.StringHashMap([]const u8).init(self.allocator),
            .allocator = self.allocator,
        };
    }

    const Attribute = struct {
        name: []const u8,
        value: []const u8,
    };

    fn readAttribute(self: *Tokenizer) !?Attribute {
        self.skipWhitespace();

        if (self.pos >= self.input.len or self.input[self.pos] == '>' or self.input[self.pos] == '/') {
            return null;
        }

        const name_start = self.pos;
        while (self.pos < self.input.len and
            !std.ascii.isWhitespace(self.input[self.pos]) and
            self.input[self.pos] != '=' and
            self.input[self.pos] != '>' and
            self.input[self.pos] != '/')
        {
            self.pos += 1;
        }

        const name = self.input[name_start..self.pos];

        if (name.len == 0) {
            return null;
        }

        self.skipWhitespace();

        if (self.pos >= self.input.len or self.input[self.pos] != '=') {
            return Attribute{ .name = name, .value = "" };
        }

        self.pos += 1; // Skip '='
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return Attribute{ .name = name, .value = "" };
        }

        const quote = self.input[self.pos];
        if (quote == '"' or quote == '\'') {
            self.pos += 1;
            const value_start = self.pos;
            while (self.pos < self.input.len and self.input[self.pos] != quote) {
                self.pos += 1;
            }
            const value = self.input[value_start..self.pos];
            if (self.pos < self.input.len) {
                self.pos += 1; // Skip closing quote
            }
            return Attribute{ .name = name, .value = value };
        } else {
            const value_start = self.pos;
            while (self.pos < self.input.len and
                !std.ascii.isWhitespace(self.input[self.pos]) and
                self.input[self.pos] != '>')
            {
                self.pos += 1;
            }
            return Attribute{ .name = name, .value = self.input[value_start..self.pos] };
        }
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }

    fn createTextToken(self: *Tokenizer, text: []const u8) Token {
        return Token{
            .type = .text,
            .data = text,
            .attributes = std.StringHashMap([]const u8).init(self.allocator),
            .allocator = self.allocator,
        };
    }
};

test "tokenizer basic" {
    const allocator = std.testing.allocator;
    const html = "<div>Hello</div>";

    var tokenizer = Tokenizer.init(allocator, html);

    var token = try tokenizer.next();
    try std.testing.expect(token.?.type == .start_tag);
    try std.testing.expectEqualStrings("div", token.?.data);
    token.?.deinit();

    token = try tokenizer.next();
    try std.testing.expect(token.?.type == .text);
    try std.testing.expectEqualStrings("Hello", token.?.data);
    token.?.deinit();

    token = try tokenizer.next();
    try std.testing.expect(token.?.type == .end_tag);
    try std.testing.expectEqualStrings("div", token.?.data);
    token.?.deinit();
}

test "tokenizer with attributes" {
    const allocator = std.testing.allocator;
    const html = "<a href=\"test.html\" class='link'>Link</a>";

    var tokenizer = Tokenizer.init(allocator, html);

    var token = try tokenizer.next();
    try std.testing.expect(token.?.type == .start_tag);
    try std.testing.expectEqualStrings("a", token.?.data);
    try std.testing.expectEqualStrings("test.html", token.?.attributes.get("href").?);
    try std.testing.expectEqualStrings("link", token.?.attributes.get("class").?);
    token.?.deinit();
}
