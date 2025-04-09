const std = @import("std");
const c = @import("ray").c;
const ecs = @import("ecs");

const conf = @import("game-config.zig");

// Rigid body
pub const RigidBody = struct {
    translation: c.Vector2 = c.Vector2Zero(),
    rot: f32 = 0.0,
    vel: f32 = 0.0,
    linvel: c.Vector2 = c.Vector2Zero(),
    angvel: f32 = 0.0,
};

// Physics
// collision layers
pub const LAYER_EMPTY: u8 = 0b0000_0000;
pub const LAYER_1: u8 = 0b0000_0001;
pub const LAYER_2: u8 = 0b0000_0010;
pub const LAYER_3: u8 = 0b0000_0100;
pub const LAYER_4: u8 = 0b0000_1000;
pub const LAYER_5: u8 = 0b0001_0000;
pub const LAYER_6: u8 = 0b0010_0000;
pub const LAYER_7: u8 = 0b0100_0000;
pub const LAYER_8: u8 = 0b1000_0000;

/// Given two layer masks returns true if collision between them can happen, false otherwise.
pub fn collisionCanHappen(layer_mask_a: u8, layer_mask_b: u8) bool {
    return layer_mask_a & layer_mask_b > 0;
}

pub const Rectangle = struct {
    width: f32,
    height: f32,
};

pub const Circle = struct {
    radius: f32,
};

/// union of possible collider shapes
pub const ColliderShape = union(enum) {
    Rectangle: Rectangle,
    Circle: Circle,
};

/// holds data of a collidable
pub const Collider = struct {
    offset: c.Vector2 = c.Vector2Zero(),
    shape: ColliderShape,
    layer_mask: u8 = LAYER_EMPTY,
};

/// holds data of a collision
pub const Collision = struct {
    entity_a: ecs.Entity,
    entity_b: ecs.Entity,
};

pub fn getRLRectangle(rect: Rectangle, offset: c.Vector2, rb_tra: c.Vector2) c.Rectangle {
    return .{
        .width = rect.width,
        .height = rect.height,
        .x = rb_tra.x + offset.x,
        .y = rb_tra.y + offset.y,
    };
}

/// If bodies are colliding returns true, false otherwise.
pub fn checkCollision(ac: Collider, arb: RigidBody, bc: Collider, brb: RigidBody) bool {
    if (!collisionCanHappen(ac.layer_mask, bc.layer_mask)) return false;

    return switch (ac.shape) {
        .Rectangle => |ars| switch (bc.shape) {
            .Rectangle => |brs| c.CheckCollisionRecs(
                getRLRectangle(ars, ac.offset, arb.translation),
                getRLRectangle(brs, bc.offset, brb.translation),
            ),
            .Circle => |bcs| c.CheckCollisionCircleRec(
                .{ .x = brb.translation.x + bc.offset.x, .y = brb.translation.y + bc.offset.y },
                bcs.radius,
                getRLRectangle(ars, ac.offset, arb.translation),
            ),
        },
        .Circle => |acs| switch (bc.shape) {
            .Rectangle => |brs| c.CheckCollisionCircleRec(
                .{ .x = arb.translation.x + ac.offset.x, .y = arb.translation.y + ac.offset.y },
                acs.radius,
                getRLRectangle(brs, bc.offset, brb.translation),
            ),
            .Circle => |bcs| c.CheckCollisionCircles(
                .{ .x = arb.translation.x + ac.offset.x, .y = arb.translation.y + ac.offset.y },
                acs.radius,
                .{ .x = brb.translation.x + bc.offset.x, .y = brb.translation.y + bc.offset.y },
                bcs.radius,
            ),
        },
    };
}

// Drawable
// TODO: implement draw layers so that things can be rendered on different layers.
// Example usage: flying things should be rendered over walking things.
pub const Drawable = struct {
    hidden: bool = false,
    tex_name: conf.TextureAssets,
    offset: c.Vector2 = c.Vector2Zero(),
    tint: c.Color,
};

// Health
pub const Health = struct {
    health: f32,
};

// Damage
pub const Damage = struct {
    damage: f32,
};

// Gun
pub const Gun = struct {
    owner: ?ecs.Entity = null,
    ammo_capacity: i32 = 0,
    /// When durability is lte 0 gun breaks, throwing gun at enemies damages them, but reduces durability.
    durability: f32 = 3.0,
    throw_damage: f32 = 10.0,
};

// Gun carrier
pub const GunCarrier = struct {
    gun: ?ecs.Entity = null,
};

// Gun magazine
pub const Ammo = struct {
    capacity: i32,
};

// Projectile
pub const Projectile = struct {
    dest: c.Vector2,
};

// Hero
pub const Hero = struct {};

// Enemy
pub const Enemy = struct {
    action_state: conf.EnemyState = .idle,
};
