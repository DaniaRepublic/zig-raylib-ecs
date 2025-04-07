const std = @import("std");

fn CustomArgs(comptime _args_type: type, comptime _state: type) type {
    return struct {
        state: _state,
        effect: ?effect_type = null,

        const Self = @This();
        const effect_type = *const fn (*Self, _args_type) void;

        fn setEffect(self: *Self, effect: effect_type) void {
            self.*.effect = effect;
        }

        fn callEffect(self: *Self, args: _args_type) void {
            if (self.*.effect) |e| {
                e(self, args);
            }
        }
    };
}

pub fn main() void {
    var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_alloc.deinit();
    const alloc = arena_alloc.allocator();

    const ArgsType = struct { arg1: i32, arg2: u8 };
    const StateType = struct { a: i32, b: []const u8 };
    const TypeCustom = CustomArgs(ArgsType, StateType);

    // // syntaxis to declare nameless functions. is it a lambda?
    // _ = struct {
    //     fn nameless() void {}
    // }.nameless;

    var custom = alloc.create(TypeCustom) catch |e| {
        std.debug.print("couldn't alloc custom: {}\n", .{e});
        return;
    };
    custom.state = .{ .a = 290, .b = "Tamarin" };
    custom.setEffect(struct {
        fn sayHi(self: *TypeCustom, args: ArgsType) void {
            std.debug.print("hi {s}, arg1: {}, arg2: {}\n", .{ self.state.b, args.arg1, args.arg2 });
        }
    }.sayHi);

    const ArgsType2 = struct { name: []const u8, age: u8 };
    const StateType2 = struct { c: u8, d: []const u8 };
    const TypeCustom2 = CustomArgs(ArgsType2, StateType2);

    var custom2 = TypeCustom2{ .state = .{ .c = 120, .d = "Sam" } };
    custom2.setEffect(struct {
        fn print(self: *TypeCustom2, args: ArgsType2) void {
            std.debug.print("custom2 effect d: {s}, args.name: {s}\n", .{ self.state.d, args.name });
        }
    }.print);

    std.debug.print("testing debug:\n", .{});
    custom.callEffect(.{ .arg1 = 330, .arg2 = 2 });
    custom.callEffect(.{ .arg1 = 101, .arg2 = 0 });

    custom2.callEffect(.{ .age = 30, .name = "Bobby" });
    custom2.callEffect(.{ .age = 19, .name = "Jackie" });
}
