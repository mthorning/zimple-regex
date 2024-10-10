const std = @import("std");
const testing = std.testing;

const Mode = enum {
    normal,
};

const Status = enum {
    pending,
    rejected,
};

const RegExp = struct {
    re: []const u8,
    str: []const u8 = undefined,
    has_start_anchor: bool = false,

    fn init(re: []const u8) RegExp {
        return .{
            .re = re,
        };
    }

    fn process(self: *RegExp, mode: Mode, re_cursor: usize, str_cursor: usize) bool {

        // If we have consumed all the regex
        if (re_cursor == self.re.len) {
            return true;
        }

        // If we have consumed all the string
        if (str_cursor == self.str.len) {

            // and have consumed all the regex
            if (re_cursor == self.re.len) return true;

            // Else, if we haven't consumed all the regex
            // then check for end anchor
            if (self.re[re_cursor] == '$' and re_cursor == self.re.len - 1) {
                return true;
            } else {
                return false;
            }
        }

        switch (self.re[re_cursor]) {
            '^' => {
                if (re_cursor == 0 and self.str.len == self.str.len) {
                    self.has_start_anchor = true;
                    return self.process(mode, 1, 0);
                }
            },
            '.' => {
                return self.process(mode, re_cursor + 1, str_cursor + 1);
            },
            else => {
                if (self.re[re_cursor] == self.str[str_cursor])
                    return self.process(mode, re_cursor + 1, str_cursor + 1);
            },
        }
        return if (self.has_start_anchor) false else self.process(mode, 0, str_cursor - re_cursor + 1);
    }

    fn matches(self: *RegExp, str: []const u8) bool {
        self.str = str;
        const is_match = self.process(Mode.normal, 0, 0);
        return is_match;
    }
};

test "Simple strings" {
    var re = RegExp.init("lo W");
    try std.testing.expect(re.matches("Hello World"));
    try std.testing.expect(!re.matches("Hello Globe"));
}

test "Start anchor" {
    var re = RegExp.init("^Hell");
    try std.testing.expect(re.matches("Hello World"));

    re = RegExp.init("^ell");
    try std.testing.expect(!re.matches("Hello World"));
}

test "End anchor" {
    var re = RegExp.init("World$");
    try std.testing.expect(re.matches("Hello World"));

    re = RegExp.init("l$");
    try std.testing.expect(!re.matches("Hello World"));
}

test "Dot" {
    var re = RegExp.init("H.l.o .o..d");
    try std.testing.expect(re.matches("Hello World"));
}
