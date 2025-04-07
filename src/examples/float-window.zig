const std = @import("std");
const c = @import("ray").c;
const gui = @import("gui");

pub fn main() void {
    // Initialize the window
    c.InitWindow(960, 560, "raygui - floating window example");
    c.SetTargetFPS(60);

    // Initialize window state variables
    var window_position: c.Vector2 = .{ .x = 10, .y = 50 };
    var window_size: c.Vector2 = .{ .x = 200, .y = 400 };
    var minimized: bool = false;
    var moving: bool = false;
    var resizing: bool = false;
    var scroll: c.Vector2 = .{ .x = 0, .y = 0 };

    var window2_position: c.Vector2 = .{ .x = 250, .y = 50 };
    var window2_size: c.Vector2 = .{ .x = 200, .y = 400 };
    var minimized2: bool = true;
    var moving2: bool = false;
    var resizing2: bool = false;
    var scroll2: c.Vector2 = .{ .x = 0, .y = 0 };

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.DARKBROWN);

        c.DrawFPS(10, 10);

        if (gui.GuiWindowFloating(&window_position, &window_size, &minimized, &moving, &resizing, gui.ExampleContent, gui.DrawContent, .{ .x = 140, .y = 320 }, &scroll, "Movable & Scalable Window")) |content| {
            std.debug.print("btn1:{} btn2:{} btn3:{}\n", .{ content.bg_btn, content.blue_btn, content.red_btn });
        }

        _ = gui.GuiWindowFloating(&window2_position, &window2_size, &minimized2, &moving2, &resizing2, gui.ExampleContent, gui.DrawContent, .{ .x = 140, .y = 320 }, &scroll2, "Another window");

        c.EndDrawing();
    }

    c.CloseWindow();
}
