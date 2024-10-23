const std = @import("std");
const testing = std.testing;

// Scalars
const SType = enum {
    literal,
    start_of_line,
    end_of_line,
    any,
};

const SToken = union(SType) {
    literal: u8,
    start_of_line,
    end_of_line,
    any,
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

fn tokenize(allocator: std.mem.Allocator, re: []const u8) ![]Token {
    var tokens = try allocator.alloc(Token, re.len);

    var re_cursor: usize = 0;
    var tokens_cursor: usize = 0;

    while (re_cursor < re.len) {
        const new_token = switch (re[re_cursor]) {
            '^' => .{ .scalar = .start_of_line },
            '$' => .{ .scalar = .end_of_line },
            '.' => .{ .scalar = .any },
            '+' => blk: {
                const one_or_more_value = tokens[tokens_cursor];
                break :blk Token{ .quantifier = .{ .one_or_more = one_or_more_value } };
            },
            else => .{ .scalar = .{ .literal = re[re_cursor] } },
        };

        tokens[tokens_cursor] = new_token;
        re_cursor += 1;
        tokens_cursor += 1;
    }

    return tokens;
}

test "basics" {
    const allocator = testing.allocator;
    const tokens = try tokenize(allocator, "^h.i$");
    defer allocator.free(tokens);

    try testing.expectEqualSlices(Token, tokens, &[_]Token{
        .{ .scalar = .start_of_line },
        .{ .scalar = .{ .literal = 'h' } },
        .{ .scalar = .any },
        .{ .scalar = .{ .literal = 'i' } },
        .{ .scalar = .end_of_line },
    });
}

// test "quantifiers" {
//     const allocator = testing.allocator;
//     const tokens = try tokenize(allocator, "h+");
//     defer allocator.free(tokens);

//     try testing.expectEqualSlices(Token, tokens, &[_]Token{
//         .{ .one_or_more = .{ .literal = 'h' } },
//     });
// }
