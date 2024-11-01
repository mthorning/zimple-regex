const std = @import("std");
const testing = std.testing;

const ReError = error{
    ReLength,
    InvalidQuantifierSubject,
};

// Scalars
const SType = enum {
    literal,
    end_of_line,
    any,
    start_of_line,
};

const SToken = union(SType) {
    literal: u8,
    end_of_line,
    any,
    start_of_line,
};

// Quantifiers
const QType = enum { one_or_more };

const QToken = union(QType) {
    one_or_more: SType,
};

const TokenType = enum {
    scalar,
    quantifier,
};

const Token = union(TokenType) {
    scalar: SToken,
    quantifier: QToken,
};

fn quantifier(tokens: *std.ArrayListAligned(Token, null), re_cursor: *usize, tokens_cursor: usize) !void {
    if (tokens_cursor == 0) return ReError.InvalidQuantifierSubject;

    switch (tokens.items[tokens_cursor - 1]) {
        Token.scalar => |token| {
            tokens.items[tokens_cursor - 1] = Token{ .quantifier = .{ .one_or_more = token } };
            re_cursor.* += 1;
        },
        else => return ReError.InvalidQuantifierSubject,
    }
}
fn tokenize(allocator: std.mem.Allocator, re: []const u8) !std.ArrayListAligned(Token, null) {
    var tokens = std.ArrayList(Token).init(allocator);

    var re_cursor: usize = 0;
    var tokens_cursor: usize = 0;

    while (re_cursor < re.len) {
        switch (re[re_cursor]) {
            '.' => try tokens.append(.{ .scalar = .any }),
            '^' => try tokens.append(.{ .scalar = .start_of_line }),
            '$' => try tokens.append(.{ .scalar = .end_of_line }),
            '\\' => {
                if (re_cursor == re.len - 1) return ReError.ReLength;
                re_cursor += 1;
                try tokens.append(.{ .scalar = .{ .literal = re[re_cursor] } });
            },
            '*' => {
                try quantifier(&tokens, &re_cursor, tokens_cursor);
                continue;
            },
            '+' => {
                try quantifier(&tokens, &re_cursor, tokens_cursor);
                continue;
            },
            else => try tokens.append(.{ .scalar = .{ .literal = re[re_cursor] } }),
        }

        re_cursor += 1;
        tokens_cursor += 1;
    }

    return tokens;
}

test "basics" {
    const allocator = testing.allocator;
    const tokens = try tokenize(allocator, "^h.i$");
    defer tokens.deinit();

    try testing.expectEqualSlices(Token, &[_]Token{
        .{ .scalar = .start_of_line },
        .{ .scalar = .{ .literal = 'h' } },
        .{ .scalar = .any },
        .{ .scalar = .{ .literal = 'i' } },
        .{ .scalar = .end_of_line },
    }, tokens.items);
}

test "quantifiers" {
    const allocator = testing.allocator;
    var tokens = try tokenize(allocator, "h+a+");

    try testing.expectEqualSlices(Token, &[_]Token{
        Token{ .quantifier = .{ .one_or_more = SToken{ .literal = 'h' } } },
        Token{ .quantifier = .{ .one_or_more = SToken{ .literal = 'a' } } },
    }, tokens.items);

    tokens.deinit();

    tokens = try tokenize(allocator, "h*a*");

    try testing.expectEqualSlices(Token, &[_]Token{
        Token{ .quantifier = .{ .one_or_more = SToken{ .literal = 'h' } } },
        Token{ .quantifier = .{ .one_or_more = SToken{ .literal = 'a' } } },
    }, tokens.items);

    tokens.deinit();

    var errorTokens = tokenize(allocator, "+");
    try testing.expectError(ReError.InvalidQuantifierSubject, errorTokens);

    errorTokens = tokenize(allocator, "+*");
    try testing.expectError(ReError.InvalidQuantifierSubject, errorTokens);

    errorTokens = tokenize(allocator, "*+");
    try testing.expectError(ReError.InvalidQuantifierSubject, errorTokens);
}

test "escaping" {
    const allocator = testing.allocator;
    var tokens = try tokenize(allocator, "h\\+");

    try testing.expectEqualSlices(Token, &[_]Token{
        Token{ .scalar = .{ .literal = 'h' } },
        Token{ .scalar = .{ .literal = '+' } },
    }, tokens.items);

    tokens.deinit();

    tokens = try tokenize(allocator, "\\\\");

    try testing.expectEqualSlices(Token, &[_]Token{
        Token{ .scalar = .{ .literal = '\\' } },
    }, tokens.items);

    tokens.deinit();

    tokens = try tokenize(allocator, "\\h");

    try testing.expectEqualSlices(Token, &[_]Token{
        Token{ .scalar = .{ .literal = 'h' } },
    }, tokens.items);

    tokens.deinit();
}
