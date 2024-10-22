const std = @import("std");
const testing = std.testing;

const TokenType = enum {
    start_of_line,
    end_of_line,
    literal,
    any,
};

const Token = union(TokenType) {
    start_of_line,
    end_of_line,
    literal: u8,
    any,
};

fn tokenize(allocator: std.mem.Allocator, re: []const u8) ![]Token {
    var tokens = try allocator.alloc(Token, re.len);

    var re_cursor: usize = 0;
    var tokens_cursor: usize = 0;

    while (re_cursor < re.len) {
        tokens[tokens_cursor] = switch (re[re_cursor]) {
            '^' => Token.start_of_line,
            '$' => Token.end_of_line,
            '.' => Token.any,
            else => Token{ .literal = re[re_cursor] },
        };

        re_cursor += 1;
        tokens_cursor += 1;
    }

    return tokens;
}

test tokenize {
    const allocator = testing.allocator;
    const tokens = try tokenize(allocator, "^h.i$");
    defer allocator.free(tokens);

    try testing.expectEqualSlices(Token, tokens, &[_]Token{
        .start_of_line,
        .{ .literal = 'h' },
        .any,
        .{ .literal = 'i' },
        .end_of_line,
    });
}
