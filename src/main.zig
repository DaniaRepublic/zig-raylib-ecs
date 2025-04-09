const std = @import("std");
const builtin = @import("builtin");
const c = @import("ray").c;
const gui = @import("gui");
const ecs = @import("ecs");

/// Game config
const conf = @import("game-config.zig");
/// Game components
const comps = @import("components.zig");

var Sfc64 = std.Random.Sfc64.init(0);
const Random = Sfc64.random();

// config window vars
var window_width: i32 = 600;
var window_height: i32 = 400;

fn setCurrWindowDims() void {
    window_width = @as(i32, c.GetScreenWidth());
    window_height = @as(i32, c.GetScreenHeight());
}

pub const PlayerCameraContainer = struct {
    camera: c.Camera2D,
};

pub fn main() !void {
    // --- setup ---
    // var arena_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena_alloc.deinit();
    // const alloc = arena_alloc.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // configure window
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE & c.FLAG_WINDOW_HIGHDPI);
    c.InitWindow(window_width, window_height, "Gun11");
    defer c.CloseWindow();

    c.SetWindowPosition(0, 0);

    const curr_mon = c.GetCurrentMonitor();

    // // have to comment out on mac as inability to wake up from sleep system call is too slow and causes stuttering.
    // const mon_refresh_rate = c.GetMonitorRefreshRate(curr_mon);
    // c.SetTargetFPS(mon_refresh_rate);

    window_width = @as(i32, c.GetMonitorWidth(curr_mon));
    window_height = @as(i32, c.GetMonitorHeight(curr_mon));
    switch (builtin.os.tag) {
        .macos => {
            window_height -= 50; // add offset for mac because of the notch
        },
        else => {},
    }

    c.SetWindowSize(window_width, window_height);

    var camera = c.Camera2D{ .zoom = 1.0 };
    camera.offset = c.Vector2{ .x = @as(f32, @floatFromInt(window_width)) / 2.0, .y = @as(f32, @floatFromInt(window_height)) / 2 };

    const player_camera_container = PlayerCameraContainer{ .camera = camera };

    var asset_storage = conf.AssetStorage.init(alloc);
    defer asset_storage.deinit();

    var reg = ecs.Registry.init(alloc);
    defer reg.deinit();
    defer deinitContexts(&reg, alloc);

    reg.setContext(&asset_storage);
    reg.setContext(&player_camera_container);

    const player_entity = try createEntities(&reg);

    // Make group with colliders owning as it seems to be the largest group. Up to change.
    var collider_group = reg.group(.{
        comps.RigidBody,
        comps.Collider,
    }, .{}, .{});
    _ = &collider_group;
    var collision_group = reg.group(.{}, .{
        comps.Collision,
    }, .{});
    _ = &collision_group;
    var player_group = reg.group(.{}, .{
        comps.RigidBody,
        comps.Collider,
        comps.Drawable,
        comps.Health,
        comps.Hero,
    }, .{});
    var enemy_group = reg.group(.{}, .{
        comps.RigidBody,
        comps.Collider,
        comps.Drawable,
        comps.Health,
        comps.Enemy,
    }, .{});
    var gun_group = reg.group(.{}, .{
        comps.RigidBody,
        comps.Drawable,
        comps.Gun,
    }, .{});
    var proj_group = reg.group(.{}, .{
        comps.RigidBody,
        comps.Collider,
        comps.Drawable,
        comps.Projectile,
    }, .{});

    // // initialize floating window state variables
    // var window_position: c.Vector2 = .{ .x = 600, .y = 50 };
    // var window_size: c.Vector2 = .{ .x = 200, .y = 400 };
    // var minimized: bool = false;
    // var moving: bool = false;
    // var resizing: bool = false;
    // var scroll: c.Vector2 = .{ .x = 0, .y = 0 };

    // var i: i32 = 0;
    // ---
    while (!c.WindowShouldClose()) {
        // i += 1;
        // if (@mod(i, 100) == 1) std.debug.print("on frame {}: {} collisions exist in total\n", .{ i, collision_group.len() });

        // --- update ---
        // If systems are order dependent, then the order they get called in in here is important.
        try contextSystem(&reg);
        try playerUpdateSystem(&reg, &player_group);
        try enemyUpdateSystem(&reg, &enemy_group, player_entity);
        try gunUpdateSystem(&reg, &gun_group, player_entity);
        try projectileUpdateSystem(&reg, &proj_group);
        // detect collisions last
        // try collisionSystem(&reg, &collider_group);
        // try handleCollisionSystem(&reg, &collision_group);

        setCurrWindowDims();
        camera.offset = c.Vector2{ .x = @as(f32, @floatFromInt(window_width)) / 2.0, .y = @as(f32, @floatFromInt(window_height)) / 2 };
        const player_rb = reg.getConst(comps.RigidBody, player_entity);
        camera.target = player_rb.translation;
        // ---
        // --- draw ---
        c.BeginDrawing();
        defer c.EndDrawing();
        c.BeginMode2D(camera);
        defer c.EndMode2D();

        c.ClearBackground(conf.DARK_GRAY);

        c.DrawFPS(10, 10);

        // The order in which systems are called determines the layer assets will be drawn on.
        try projectileDrawSystem(&reg, &proj_group);
        try playerDrawSystem(&reg, &player_group);
        try enemyDrawSystem(&reg, &enemy_group);
        try gunDrawSystem(&reg, &gun_group);

        // // gui
        // if (gui.GuiWindowFloating(&window_position, &window_size, &minimized, &moving, &resizing, gui.ExampleContent, gui.DrawContent, .{ .x = 140, .y = 320 }, &scroll, "Player color switcher.")) |content| {
        //     if (content.blue_btn > 0) {
        //         player.state.tint = c.SKYBLUE;
        //     } else if (content.red_btn > 0) {
        //         player.state.tint = c.MAROON;
        //     } else if (content.bg_btn > 0) {
        //         player.state.tint = c.WHITE;
        //     }
        // }
        // ---
    }
}

fn deinitContexts(reg: *ecs.Registry, alloc: std.mem.Allocator) void {
    if (reg.getContext(conf.GameLoopCtx)) |old_context| {
        alloc.destroy(old_context);
    }
}

/// Sets GameLoopCtx context in registry. Get it after setting from anywhere with reg.getContext(GameLoopCtx).
pub fn contextSystem(reg: *ecs.Registry) !void {
    const alloc = reg.allocator;
    // destroy old context if present
    if (reg.getContext(conf.GameLoopCtx)) |old_context| {
        alloc.destroy(old_context);
    }
    const context = alloc.create(conf.GameLoopCtx) catch |err| {
        return err;
    };

    const delta_t = c.GetFrameTime();
    const mouse_pos = c.GetMousePosition();
    const kb_inputs: conf.KbInputs = .{
        .a = c.IsKeyDown(c.KEY_A),
        .d = c.IsKeyDown(c.KEY_D),
        .w = c.IsKeyDown(c.KEY_W),
        .s = c.IsKeyDown(c.KEY_S),
        .e = c.IsKeyPressed(c.KEY_E),
        .l_shift = c.IsKeyDown(c.KEY_LEFT_SHIFT),
        .l_mouse_down = c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT),
        .l_mouse_pressed = c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT),
    };
    context.* = .{
        .delta_t = delta_t,
        .mouse_pos = mouse_pos,
        .kb_inputs = kb_inputs,
    };
    reg.setContext(context);
}

/// creates collisions for each colliding entity
pub fn collisionSystem(reg: *ecs.Registry, collider_group: *ecs.OwningGroup) !void {
    var iter = collider_group.iterator(struct { rb: *comps.RigidBody, collider: *comps.Collider });
    while (iter.next()) |e| {
        var nested_iter = collider_group.iterator(struct { rb: *comps.RigidBody, collider: *comps.Collider });
        while (nested_iter.next()) |e2| {
            // if collision happens, create a new collision entity
            if (comps.checkCollision(e.collider.*, e.rb.*, e2.collider.*, e2.rb.*)) {
                const collision_entity = reg.create();
                reg.add(collision_entity, comps.Collision{
                    .entity_a = iter.entity(),
                    .entity_b = nested_iter.entity(),
                });
            }
        }
    }
}

/// handles collisions
pub fn handleCollisionSystem(reg: *ecs.Registry, collision_group: *ecs.BasicGroup) !void {
    const entities = collision_group.data();
    for (entities) |e| {
        reg.destroy(e);
    }
}

pub fn enemyUpdateSystem(reg: *ecs.Registry, enemy_group: *ecs.BasicGroup, player_entity: ecs.Entity) !void {
    const ctx = reg.getContext(conf.GameLoopCtx) orelse return error.GameLoopCtxUnavailabe;
    const player_rb = reg.get(comps.RigidBody, player_entity);

    var enemies_iter = enemy_group.iterator();
    while (enemies_iter.next()) |e| {
        const enemy = reg.get(comps.Enemy, e);
        const rb = reg.get(comps.RigidBody, e);

        const enemy_to_player = c.Vector2Subtract(player_rb.translation, rb.translation);
        const enemy_to_player_dist = c.Vector2Length(enemy_to_player);
        if (enemy_to_player_dist < 300.0) {
            enemy.action_state = .following_player;
        } else {
            enemy.action_state = .idle;
        }
        if (enemy.action_state == .following_player) {
            rb.translation = c.Vector2MoveTowards(rb.translation, player_rb.translation, rb.vel * ctx.delta_t);
        }
    }
}

fn enemyDrawSystem(reg: *ecs.Registry, enemy_group: *ecs.BasicGroup) !void {
    const asset_storage = reg.getContext(conf.AssetStorage) orelse unreachable;

    var enemies_iter = enemy_group.iterator();
    while (enemies_iter.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const drawable = reg.getConst(comps.Drawable, e);

        const tex = asset_storage.getTex(drawable.tex_name) orelse unreachable;
        c.DrawTextureV(tex.*, rb.translation, drawable.tint);
    }
}

fn playerUpdateSystem(reg: *ecs.Registry, player_group: *ecs.BasicGroup) !void {
    const ctx = reg.getContext(conf.GameLoopCtx) orelse return error.GameLoopCtxUnavailabe;
    const delta_t = ctx.delta_t;
    const kb_inputs = ctx.kb_inputs;

    var move_vec = c.Vector2Zero();
    if (kb_inputs.a) {
        move_vec.x -= 1;
    }
    if (kb_inputs.d) {
        move_vec.x += 1;
    }
    if (kb_inputs.w) {
        move_vec.y -= 1;
    }
    if (kb_inputs.s) {
        move_vec.y += 1;
    }

    if (c.Vector2Length(move_vec) > 0) {
        var player_iter = player_group.iterator();
        while (player_iter.next()) |e| {
            const rb = reg.get(comps.RigidBody, e);
            const health = reg.get(comps.Health, e);
            _ = health;
            move_vec = c.Vector2Normalize(move_vec);
            move_vec = c.Vector2Scale(move_vec, rb.vel * delta_t);
            if (kb_inputs.l_shift) {
                move_vec = c.Vector2Scale(move_vec, 1.5);
            }
            rb.translation = c.Vector2Add(rb.translation, move_vec);
        }
    }
}

fn playerDrawSystem(reg: *ecs.Registry, player_group: *ecs.BasicGroup) !void {
    const asset_storage = reg.getContext(conf.AssetStorage) orelse unreachable;

    var player_iter_draw = player_group.iterator();
    while (player_iter_draw.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const drawable = reg.get(comps.Drawable, e);

        const tex = asset_storage.getTex(drawable.tex_name) orelse unreachable;

        const tex_half_extents = c.Vector2{
            .x = @as(f32, @floatFromInt(tex.width)) / 2.0,
            .y = @as(f32, @floatFromInt(tex.height)) / 2.0,
        };
        const source_rect = c.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(tex.width)),
            .height = @as(f32, @floatFromInt(tex.height)),
        };
        const tex_pos = c.Vector2Subtract(rb.translation, tex_half_extents);
        const dest_rect = c.Rectangle{
            .x = tex_pos.x,
            .y = tex_pos.y,
            .width = @as(f32, @floatFromInt(tex.width)) * 2,
            .height = @as(f32, @floatFromInt(tex.height)) * 2,
        };
        c.DrawTexturePro(tex.*, source_rect, dest_rect, tex_half_extents, 0.0, drawable.tint);
    }
}

fn projectileUpdateSystem(reg: *ecs.Registry, proj_group: *ecs.BasicGroup) !void {
    const ctx = reg.getContext(conf.GameLoopCtx) orelse unreachable;

    var projs_to_destroy = std.ArrayList(ecs.Entity).init(reg.allocator);
    defer projs_to_destroy.deinit();

    var iter = proj_group.iterator();
    while (iter.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const proj = reg.get(comps.Projectile, e);
        const new_pos = c.Vector2MoveTowards(rb.translation, proj.dest, rb.vel * ctx.delta_t);
        rb.translation = new_pos;

        // destroy bullet when it reaches destination
        if (c.Vector2Distance(new_pos, proj.dest) < 0.01) {
            try projs_to_destroy.append(e);
        }
    }

    for (projs_to_destroy.items) |e| {
        reg.destroy(e);
    }
}

fn projectileDrawSystem(reg: *ecs.Registry, proj_group: *ecs.BasicGroup) !void {
    const asset_storage = reg.getContext(conf.AssetStorage) orelse unreachable;

    var iter = proj_group.iterator();
    while (iter.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const drawable = reg.get(comps.Drawable, e);

        const tex = asset_storage.getTex(drawable.tex_name) orelse unreachable;

        const tex_half_extents = c.Vector2{
            .x = @as(f32, @floatFromInt(tex.width)) / 2.0,
            .y = @as(f32, @floatFromInt(tex.height)) / 2.0,
        };
        const source_rect = c.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(tex.width)),
            .height = @as(f32, @floatFromInt(tex.height)),
        };
        // get world position from screen position
        const tex_pos = c.Vector2Subtract(rb.translation, tex_half_extents);
        const dest_rect = c.Rectangle{
            .x = tex_pos.x,
            .y = tex_pos.y,
            .width = @as(f32, @floatFromInt(tex.width)),
            .height = @as(f32, @floatFromInt(tex.height)),
        };
        c.DrawTexturePro(tex.*, source_rect, dest_rect, tex_half_extents, rb.rot, drawable.tint);
    }
}

fn gunUpdateSystem(reg: *ecs.Registry, gun_group: *ecs.BasicGroup, player_entity: ecs.Entity) !void {
    const ctx = reg.getContext(conf.GameLoopCtx) orelse unreachable;

    const player_rb = reg.get(comps.RigidBody, player_entity);
    const player_gun_carrier = reg.get(comps.GunCarrier, player_entity);

    // look through guns that have owners first so that gun drops are proccessed before picking.
    // use parallel arrays to store components
    var rbs_owned = std.ArrayList(*comps.RigidBody).init(reg.allocator);
    defer rbs_owned.deinit();
    var guns_owned = std.ArrayList(*comps.Gun).init(reg.allocator);
    defer guns_owned.deinit();
    var entities_owned = std.ArrayList(ecs.Entity).init(reg.allocator);
    defer entities_owned.deinit();

    var rbs_not_owned = std.ArrayList(*comps.RigidBody).init(reg.allocator);
    defer rbs_not_owned.deinit();
    var guns_not_owned = std.ArrayList(*comps.Gun).init(reg.allocator);
    defer guns_not_owned.deinit();
    var entities_not_owned = std.ArrayList(ecs.Entity).init(reg.allocator);
    defer entities_not_owned.deinit();

    var iter = gun_group.iterator();
    while (iter.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const gun = reg.get(comps.Gun, e);

        if (gun.owner) |_| {
            try rbs_owned.append(rb);
            try guns_owned.append(gun);
            try entities_owned.append(e);
        } else {
            try rbs_not_owned.append(rb);
            try guns_not_owned.append(gun);
            try entities_not_owned.append(e);
        }
    }

    for (0..rbs_owned.items.len) |i| {
        const rb = rbs_owned.items[i];
        const gun = guns_owned.items[i];
        const e = entities_owned.items[i];
        _ = e;

        if (gun.owner) |owner_entity| blk: {
            const owner_carrier = reg.get(comps.GunCarrier, owner_entity);
            const owner_rb = reg.get(comps.RigidBody, owner_entity);
            rb.translation = owner_rb.translation;

            const player_to_pointer_vec = c.Vector2Subtract(ctx.mouse_pos, c.Vector2{ .x = @as(f32, @floatFromInt(window_width)) / 2.0, .y = @as(f32, @floatFromInt(window_height)) / 2.0 });
            if (c.Vector2Length(player_to_pointer_vec) > 10.0) {
                const ang = c.Vector2Angle(.{ .x = 1.0, .y = 0.0 }, player_to_pointer_vec) / std.math.pi * 180.0;
                const diff = @mod(ang - rb.rot + 180.0, 360.0) - 180.0;
                rb.rot += diff * 10.0 * ctx.delta_t;
            }

            // If owner decides to throw the gun, launch it in the direction they're looking in
            if (ctx.kb_inputs.e) {
                gun.owner = null;
                owner_carrier.gun = null;
                break :blk;
            }

            // handle firing bullet
            if (ctx.kb_inputs.l_mouse_pressed) {
                const player_camera_container = reg.getContext(PlayerCameraContainer) orelse unreachable;
                const world_pos = c.GetScreenToWorld2D(c.Vector2Add(ctx.mouse_pos, rb.translation), player_camera_container.camera);
                try createBullet(reg, rb.translation, world_pos);
            }
        }
    }

    for (0..rbs_not_owned.items.len) |i| {
        const rb = rbs_not_owned.items[i];
        const gun = guns_not_owned.items[i];
        const e = entities_not_owned.items[i];

        // If player in vacinity - let them pick up the gun
        if (c.Vector2Distance(player_rb.translation, rb.translation) < 50.0 and ctx.kb_inputs.e and gun.owner == null and player_gun_carrier.gun == null) {
            gun.owner = player_entity;
            player_gun_carrier.gun = e;
            break;
        }
    }
}

fn gunDrawSystem(reg: *ecs.Registry, gun_group: *ecs.BasicGroup) !void {
    const asset_storage = reg.getContext(conf.AssetStorage) orelse unreachable;

    var gun_iter = gun_group.iterator();
    while (gun_iter.next()) |e| {
        const rb = reg.get(comps.RigidBody, e);
        const gun = reg.get(comps.Gun, e);
        const drawable = reg.get(comps.Drawable, e);
        const tex = asset_storage.getTex(drawable.tex_name) orelse unreachable;

        const origin = c.Vector2{ .x = 0.0, .y = 0.0 };
        const gun_source_rect = c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, @floatFromInt(tex.width)), .height = @as(f32, @floatFromInt(tex.height)) };
        const gun_dest_rect = c.Rectangle{ .x = rb.translation.x, .y = rb.translation.y, .width = @as(f32, @floatFromInt(tex.width)) * 0.1, .height = @as(f32, @floatFromInt(tex.height)) * 0.1 };

        // entity wearing gun
        if (gun.owner) |owner_entity| {
            const owner_drawable = reg.get(comps.Drawable, owner_entity);
            const owner_tex = asset_storage.getTex(owner_drawable.tex_name) orelse unreachable;

            const owner_tex_half_extents = c.Vector2{
                .x = @as(f32, @floatFromInt(owner_tex.width)) / 2.0,
                .y = @as(f32, @floatFromInt(owner_tex.height)) / 2.0,
            };

            c.DrawTexturePro(tex.*, gun_source_rect, gun_dest_rect, c.Vector2Subtract(owner_tex_half_extents, origin), rb.rot, drawable.tint);
        }
        // gun floating on it's spot
        else {
            c.DrawTexturePro(tex.*, gun_source_rect, gun_dest_rect, origin, rb.rot, drawable.tint);
        }
    }
}

/// Creates game entities and returns players entity
fn createEntities(reg: *ecs.Registry) !ecs.Entity {
    const asset_storage = reg.getContext(conf.AssetStorage) orelse unreachable;

    // initialize enemy
    _ = try asset_storage.createAddTex(.enemy_default, conf.RESOURCES_BASE_PATH ++ "orange-eye-enemy.png");

    for (0..10000) |_| {
        const entity = reg.create();
        reg.add(entity, comps.Enemy{
            .action_state = .idle,
        });
        reg.add(entity, comps.RigidBody{
            .vel = 100,
            .angvel = 0,
            .linvel = .{ .x = 0, .y = 0 },
            .translation = .{
                .x = @as(f32, @floatFromInt(std.Random.intRangeAtMostBiased(Random, i32, 0, window_width))),
                .y = @as(f32, @floatFromInt(std.Random.intRangeAtMostBiased(Random, i32, 0, window_height))),
            },
        });
        reg.add(entity, comps.Collider{
            .layer_mask = comps.LAYER_1 | comps.LAYER_4,
            .shape = .{ .Rectangle = .{ .width = 10, .height = 20 } },
        });
        reg.add(entity, comps.Drawable{
            .hidden = false,
            .tex_name = .enemy_default,
            .tint = c.WHITE,
        });
        reg.add(entity, comps.Health{
            .health = 100,
        });
        reg.add(entity, comps.GunCarrier{});
    }

    // initialize player
    _ = try asset_storage.createAddTex(.hero_default, conf.RESOURCES_BASE_PATH ++ "yellow-smiler.png");

    const player_entity = reg.create();
    reg.add(player_entity, comps.Hero{});
    reg.add(player_entity, comps.RigidBody{
        .vel = 100,
        .angvel = 0,
        .linvel = .{ .x = 0, .y = 0 },
        .translation = .{ .x = 100, .y = 100 },
    });
    reg.add(player_entity, comps.Collider{
        .layer_mask = comps.LAYER_1,
        .shape = .{ .Rectangle = .{ .width = 40, .height = 50 } },
    });
    reg.add(player_entity, comps.Drawable{
        .hidden = false,
        .tex_name = .hero_default,
        .tint = c.WHITE,
    });
    reg.add(player_entity, comps.Health{
        .health = 100,
    });
    reg.add(player_entity, comps.GunCarrier{});

    // initialize bullet for gun
    _ = try asset_storage.createAddTex(.bullet_default, conf.RESOURCES_BASE_PATH ++ "bullet-fin.png");

    // initialize gun
    _ = try asset_storage.createAddTex(.gun_default, conf.RESOURCES_BASE_PATH ++ "PR42A-6mm-Assault-Rifle.png");

    const gun_entity = reg.create();
    reg.add(gun_entity, comps.RigidBody{
        .vel = 0,
        .angvel = 0,
        .linvel = .{ .x = 0, .y = 0 },
        .translation = .{ .x = 300, .y = 300 },
    });
    reg.add(gun_entity, comps.Drawable{
        .hidden = false,
        .tex_name = .gun_default,
        .tint = c.WHITE,
    });
    reg.add(gun_entity, comps.Gun{
        .owner = null,
    });

    const gun_entity2 = reg.create();
    reg.add(gun_entity2, comps.RigidBody{
        .vel = 0,
        .angvel = 0,
        .linvel = .{ .x = 0, .y = 0 },
        .translation = .{ .x = 300, .y = 200 },
    });
    reg.add(gun_entity2, comps.Drawable{
        .hidden = false,
        .tex_name = .gun_default,
        .tint = c.RED,
    });
    reg.add(gun_entity2, comps.Gun{
        .owner = null,
    });

    return player_entity;
}

pub fn createBullet(reg: *ecs.Registry, pos: c.Vector2, target: c.Vector2) !void {
    const rot = c.Vector2Angle(.{ .x = 1.0, .y = 0.0 }, c.Vector2Subtract(target, pos)) / std.math.pi * 180.0;

    const bullet_entity = reg.create();
    // create bullet on some trigger
    reg.add(bullet_entity, comps.RigidBody{
        .vel = 700,
        .linvel = .{ .x = 0, .y = 0 },
        .angvel = 0,
        .rot = rot,
        .translation = pos,
    });
    reg.add(bullet_entity, comps.Collider{
        .layer_mask = comps.LAYER_4,
        .shape = .{ .Rectangle = .{ .width = 10, .height = 5 } },
    });
    reg.add(bullet_entity, comps.Drawable{
        .hidden = false,
        .tex_name = .bullet_default,
        .tint = c.WHITE,
    });
    reg.add(bullet_entity, comps.Damage{
        .damage = 80,
    });
    reg.add(bullet_entity, comps.Projectile{
        .dest = target,
    });
}
