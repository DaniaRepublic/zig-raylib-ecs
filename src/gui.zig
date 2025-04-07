const std = @import("std");
const c = @import("ray").c;

pub const ExampleContent = struct {
    red_btn: c_int,
    blue_btn: c_int,
    bg_btn: c_int,
};

/// Floating window drawing function.
/// - `position`, `size`, `minimized`, `moving`, `resizing`, and `scroll` are pointers to the state for this window.
/// - `draw_content` is a function pointer to a callback to render window contents.
/// - `content_size` defines the content area.
/// - `title` is the window title.
pub fn GuiWindowFloating(
    position: *c.Vector2,
    size: *c.Vector2,
    minimized: *bool,
    moving: *bool,
    resizing: *bool,
    comptime T: type,
    draw_content: fn (c.Vector2, c.Vector2) T,
    content_size: c.Vector2,
    scroll: *c.Vector2,
    title: [*:0]const u8,
) ?T {
    var content: ?T = null;
    const RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT: i32 = 24;
    const RAYGUI_WINDOW_CLOSEBUTTON_SIZE: i32 = 18;
    const close_title_size_delta_half = (RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT - RAYGUI_WINDOW_CLOSEBUTTON_SIZE) / 2;

    // Handle window movement and resize input
    if (c.IsMouseButtonPressed(c.MOUSE_LEFT_BUTTON) and (!(moving.*)) and (!(resizing.*))) {
        const mouse_position: c.Vector2 = c.GetMousePosition();

        const title_collision_rect: c.Rectangle = .{
            .x = position.*.x,
            .y = position.*.y,
            .width = size.*.x - (RAYGUI_WINDOW_CLOSEBUTTON_SIZE + close_title_size_delta_half),
            .height = RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT,
        };

        const resize_collision_rect: c.Rectangle = .{
            .x = position.*.x + size.*.x - 20,
            .y = position.*.y + size.*.y - 20,
            .width = 20,
            .height = 20,
        };

        if (c.CheckCollisionPointRec(mouse_position, title_collision_rect)) {
            moving.* = true;
        } else if (!(minimized.*) and c.CheckCollisionPointRec(mouse_position, resize_collision_rect)) {
            resizing.* = true;
        }
    }

    // Update movement and resizing
    if (moving.*) {
        const mouse_delta: c.Vector2 = c.GetMouseDelta();
        position.*.x += mouse_delta.x;
        position.*.y += mouse_delta.y;

        if (c.IsMouseButtonReleased(c.MOUSE_LEFT_BUTTON)) {
            moving.* = false;
            // Clamp position inside the application area
            if (position.*.x < 0) {
                position.*.x = 0;
            } else if (position.*.x > @as(f32, @floatFromInt(c.GetScreenWidth())) - size.*.x) {
                position.*.x = @as(f32, @floatFromInt(c.GetScreenWidth())) - size.*.x;
            }
            if (position.*.y < 0) {
                position.*.y = 0;
            } else if (position.*.y > @as(f32, @floatFromInt(c.GetScreenHeight())) - RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT) {
                position.*.y = @as(f32, @floatFromInt(c.GetScreenHeight())) - RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT;
            }
        }
    } else if (resizing.*) {
        const mouse: c.Vector2 = c.GetMousePosition();
        if (mouse.x > position.*.x) {
            size.*.x = mouse.x - position.*.x;
        }
        if (mouse.y > position.*.y) {
            size.*.y = mouse.y - position.*.y;
        }
        // Clamp window size to a minimum value and the screen dimensions
        if (size.*.x < 100) {
            size.*.x = 100;
        } else if (size.*.x > @as(f32, @floatFromInt(c.GetScreenWidth()))) {
            size.*.x = @as(f32, @floatFromInt(c.GetScreenWidth()));
        }
        if (size.*.y < 100) {
            size.*.y = 100;
        } else if (size.*.y > @as(f32, @floatFromInt(c.GetScreenHeight()))) {
            size.*.y = @as(f32, @floatFromInt(c.GetScreenHeight()));
        }

        if (c.IsMouseButtonReleased(c.MOUSE_LEFT_BUTTON)) {
            resizing.* = false;
        }
    }

    // Drawing window contents
    if (minimized.*) {
        const statusBarRect: c.Rectangle = .{
            .x = position.*.x,
            .y = position.*.y,
            .width = size.*.x,
            .height = RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT,
        };
        _ = c.GuiStatusBar(statusBarRect, title);

        const closeButtonRect: c.Rectangle = .{
            .x = position.*.x + size.*.x - RAYGUI_WINDOW_CLOSEBUTTON_SIZE - close_title_size_delta_half,
            .y = position.*.y + close_title_size_delta_half,
            .width = RAYGUI_WINDOW_CLOSEBUTTON_SIZE,
            .height = RAYGUI_WINDOW_CLOSEBUTTON_SIZE,
        };
        if (c.GuiButton(closeButtonRect, "#120#") > 0) {
            minimized.* = false;
        }
    } else {
        minimized.* = c.GuiWindowBox(.{
            .x = position.*.x,
            .y = position.*.y,
            .width = size.*.x,
            .height = size.*.y,
        }, title) > 0;

        // Create scroll panel and clip contents if necessary
        var scissor: c.Rectangle = undefined;
        _ = c.GuiScrollPanel(.{
            .x = position.*.x,
            .y = position.*.y + RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT,
            .width = size.*.x,
            .height = size.*.y - RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT,
        }, null, .{
            .x = position.*.x,
            .y = position.*.y,
            .width = content_size.x,
            .height = content_size.y,
        }, scroll, &scissor);

        const require_scissor = size.*.x < content_size.x or size.*.y < content_size.y;
        if (require_scissor) {
            c.BeginScissorMode(@as(c_int, @intFromFloat(scissor.x)), @as(c_int, @intFromFloat(scissor.y)), @as(c_int, @intFromFloat(scissor.width)), @as(c_int, @intFromFloat(scissor.height)));
        }

        content = draw_content(position.*, scroll.*);

        if (require_scissor) {
            c.EndScissorMode();
        }

        // Draw the resize button/icon
        c.GuiDrawIcon(71, @as(c_int, @intFromFloat(position.*.x + size.*.x - 20)), @as(c_int, @intFromFloat(position.*.y + size.*.y - 20)), 1, c.DARKGRAY);
    }

    return content;
}

/// Draws the content of the window.
pub fn DrawContent(position: c.Vector2, scroll: c.Vector2) ExampleContent {
    const btnRect1: c.Rectangle = .{
        .x = position.x + 20 + scroll.x,
        .y = position.y + 50 + scroll.y,
        .width = 100,
        .height = 25,
    };
    const red_btn = c.GuiButton(btnRect1, "Red");

    const btnRect2: c.Rectangle = .{
        .x = position.x + 20 + scroll.x,
        .y = position.y + 100 + scroll.y,
        .width = 100,
        .height = 25,
    };
    const blue_btn = c.GuiButton(btnRect2, "Blue");

    const btnRect3: c.Rectangle = .{
        .x = position.x + 20 + scroll.x,
        .y = position.y + 150 + scroll.y,
        .width = 100,
        .height = 25,
    };
    const bg_btn = c.GuiButton(btnRect3, "bg");

    return .{
        .red_btn = red_btn,
        .blue_btn = blue_btn,
        .bg_btn = bg_btn,
    };
}
