const std = @import("std");

pub const tokenizer = @import("tokenizer.zig");
pub const node = @import("node.zig");
pub const parser = @import("parser.zig");
pub const selector = @import("selector.zig");
pub const query = @import("query.zig");
pub const streaming = @import("streaming.zig");

pub const Tokenizer = tokenizer.Tokenizer;
pub const Token = tokenizer.Token;
pub const TokenType = tokenizer.TokenType;
pub const Node = node.Node;
pub const NodeType = node.NodeType;
pub const Parser = parser.Parser;
pub const Selector = selector.Selector;
pub const StreamingParser = streaming.StreamingParser;
pub const MatchResult = streaming.MatchResult;

pub const querySelector = query.querySelector;
pub const querySelectorAll = query.querySelectorAll;
pub const querySelectorAllText = query.querySelectorAllText;
pub const querySelectorAttribute = query.querySelectorAttribute;

test {
    std.testing.refAllDecls(@This());
}
