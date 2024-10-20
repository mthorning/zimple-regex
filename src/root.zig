const std = @import("std");
const testing = std.testing;

const Mode = enum { normal, not_special, quantifier };

const Status = enum {
    pending,
    rejected,
    matched,
};

const RegExp = struct {
    re: []const u8,
    str: []const u8 = undefined,
    str_start_loc: usize = 0,
    has_start_anchor: bool = false,

    fn init(re: []const u8) RegExp {
        return .{
            .re = re,
        };
    }

    fn checkLengths(self: *RegExp, re_cursor: usize, str_cursor: usize) Status {
        // If we have consumed all the regex
        const re_len = self.re.len;
        _ = re_len;
        const str_len = self.str.len;
        _ = str_len;

        if (re_cursor == self.re.len) {
            return Status.matched;
        }

        // If we have consumed all the string
        if (str_cursor == self.str.len) {

            // and have consumed all the regex
            if (re_cursor == self.re.len) return Status.matched;

            // Else, if we haven't consumed all the regex
            // then check for end anchor
            if (self.re[re_cursor] == '$' and re_cursor == self.re.len - 1) {
                return Status.matched;
            } else {
                return Status.rejected;
            }
        }
        return Status.pending;
    }

    fn processSpecialChars(self: *RegExp, mode: Mode, re_cursor: usize, str_cursor: usize) bool {
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
            '\\' => {
                return self.process(Mode.not_special, re_cursor + 1, str_cursor);
            },
            '*' => {
                return self.process(Mode.quantifier, re_cursor - 1, str_cursor);
            },
            '+' => {
                return self.process(Mode.quantifier, re_cursor - 1, str_cursor);
            },
            else => {},
        }
        return self.process(Mode.not_special, re_cursor, str_cursor);
    }

    fn process(self: *RegExp, mode: Mode, re_cursor: usize, str_cursor: usize) bool {
        switch (self.checkLengths(re_cursor, str_cursor)) {
            Status.matched => return true,
            Status.rejected => return false,
            else => {},
        }

        switch (mode) {
            Mode.normal => {
                return self.processSpecialChars(mode, re_cursor, str_cursor);
            },
            Mode.not_special => {
                if (self.re[re_cursor] == self.str[str_cursor])
                    return self.process(Mode.normal, re_cursor + 1, str_cursor + 1);
            },
            Mode.quantifier => {
                if (self.re[re_cursor] == self.str[str_cursor]) {
                    return self.process(mode, re_cursor, str_cursor + 1);
                } else {
                    return self.process(Mode.normal, re_cursor + 2, str_cursor);
                }
            },
        }

        if (self.has_start_anchor) return false;

        // If the next re char is * then we can carry on
        if (re_cursor + 1 <= (self.re.len - 1) and self.re[re_cursor + 1] == '*') {
            return if (re_cursor + 2 <= (self.re.len - 1))
                self.process(Mode.normal, re_cursor + 2, str_cursor)
            else
                true;
        }

        self.str_start_loc += 1;
        return self.process(mode, 0, self.str_start_loc);
    }

    fn matches(self: *RegExp, str: []const u8) bool {
        self.str = str;
        const is_match = self.process(Mode.normal, 0, 0);
        return is_match;
    }
};

test "Simple strings" {
    var re = RegExp.init("lo W");
    try testing.expect(re.matches("Hello World"));
    try testing.expect(!re.matches("Hello Globe"));
}

test "Start anchor" {
    var re = RegExp.init("^Hell");
    try testing.expect(re.matches("Hello World"));

    re = RegExp.init("^ell");
    try testing.expect(!re.matches("Hello World"));
}

test "End anchor" {
    var re = RegExp.init("World$");
    try testing.expect(re.matches("Hello World"));

    re = RegExp.init("l$");
    try testing.expect(!re.matches("Hello World"));
}

test "Dot" {
    var re = RegExp.init("H.l.o .o..d");
    try testing.expect(re.matches("Hello World"));
}

test "Backslash" {
    var re = RegExp.init("H\\.ll\\*\\+o");
    try testing.expect(re.matches("H.ll*+o"));
    try testing.expect(!re.matches("Hello"));
}

test "Asterisk quantifier" {
    var re = RegExp.init("Wo*rld");
    try testing.expect(re.matches("Wrld"));
    try testing.expect(re.matches("Woorld"));
    try testing.expect(re.matches("Woooorld"));
    try testing.expect(!re.matches("Wirld"));
}

test "Plus quantifier" {
    var re = RegExp.init("Wo+rld");
    try testing.expect(re.matches("Woorld"));
    try testing.expect(re.matches("Woooorld"));
    try testing.expect(!re.matches("Wrld"));
    try testing.expect(!re.matches("Wirld"));
}
