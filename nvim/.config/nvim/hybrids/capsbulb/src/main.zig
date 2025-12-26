const std = @import("std");
const c = @cImport({
    @cInclude("X11/XKBlib.h");
});

var disp: ?*c.Display = undefined;

fn getStateImpl() !c_int {
    if (disp == null) {
        const dispname = std.posix.getenv("DISPLAY");
        if (dispname == null) return error.NO_DISPLAY;
        disp = c.XOpenDisplay(dispname.?);
    }

    var state: c_uint = undefined;

    if (c.XkbGetIndicatorState(disp, c.XkbUseCoreKbd, &state) != c.Success)
        return error.INACCESSIBLE_INDICATOR_STATE;

    return @intCast(state);
}

export fn capsbulb_state() c_int {
    return getStateImpl() catch 0;
}

pub fn main() !void {
    const state = try getStateImpl();
    std.debug.print("caps lock is {s}\n", .{if (state == 1) "on" else "off"});
}
