const std = @import("std");
const c = @import("ray").c;
const ecs = @import("ecs");

const conf = @import("game-config.zig");

// Rigid body
pub const RigidBody = struct {
    translation: c.Vector2 = c.Vector2Zero(),
    /// Used in collision resolution
    mass: f32 = 1.0,
    rot: f32 = 0.0,
    linvel: c.Vector2 = c.Vector2Zero(),
    angvel: f32 = 0.0,
    affected_by_forces: bool = true,
    /// Move speed of entity
    vel_scalar: f32 = 100.0,
};

// Physics
// collision slop distance
const SLOP_DIST: f32 = 1.0;
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

/// Given two colliders returns true if collision between them can happen, false otherwise.
pub fn collisionCanHappen(a: Collider, b: Collider) bool {
    return (a.layer_mask & b.layer_mask > 0) and ((a.layer_exclude & b.layer_mask < b.layer_mask) or
        (b.layer_exclude & a.layer_mask < a.layer_mask));
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
    /// If another collider has the same component in the mask, they will collide
    layer_mask: u8 = LAYER_EMPTY,
    /// Excludes colliders that are covered by this mask
    layer_exclude: u8 = LAYER_EMPTY,
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
    if (!collisionCanHappen(ac, bc)) return false;

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

pub fn computeLinvels(m1: f32, v1: c.Vector2, m2: f32, v2: c.Vector2, n: c.Vector2, e: f32) struct { c.Vector2, c.Vector2 } {
    const v_rel = c.Vector2DotProduct(c.Vector2Subtract(v2, v1), n);
    const j = v_rel * -(1 + e) / (1 / m1 + 1 / m2);
    return .{ c.Vector2Subtract(v1, c.Vector2Scale(n, j / m1)), c.Vector2Add(v2, c.Vector2Scale(n, j / m2)) };
}

/// Resolves collision. Assumes that entities in collision struct indeed collide.
pub fn resolveCollision(reg: *ecs.Registry, collision: Collision) !void {
    const arb = reg.get(RigidBody, collision.entity_a);
    const ac = reg.getConst(Collider, collision.entity_a);
    const brb = reg.get(RigidBody, collision.entity_b);
    const bc = reg.getConst(Collider, collision.entity_b);

    switch (ac.shape) {
        .Rectangle => |ars| switch (bc.shape) {
            .Rectangle => |brs| {
                var n = c.Vector2Normalize(c.Vector2Subtract(arb.translation, brb.translation));
                if (c.Vector2LengthSqr(n) < 0.0001) {
                    n = c.Vector2{ .x = 1.0, .y = 0.0 }; // arbitrary fallback
                }
                const new_linvel_a, const new_linvel_b = computeLinvels(arb.mass, arb.linvel, brb.mass, brb.linvel, n, 0.9);
                arb.linvel = new_linvel_a;
                brb.linvel = new_linvel_b;

                const ac_tra = c.Vector2{ .x = arb.translation.x + ac.offset.x, .y = arb.translation.y + ac.offset.y };
                const bc_tra = c.Vector2{ .x = brb.translation.x + bc.offset.x, .y = brb.translation.y + bc.offset.y };

                // overlap
                const a_x: f32 = ac_tra.x + ars.width - bc_tra.x;
                const b_x: f32 = bc_tra.x + brs.width - ac_tra.x;
                const x_overlap: f32 = @min(a_x, b_x);

                const a_y: f32 = ac_tra.y + ars.height - bc_tra.y;
                const b_y: f32 = bc_tra.y + brs.height - ac_tra.y;
                const y_overlap: f32 = @min(a_y, b_y);

                if (x_overlap < SLOP_DIST or y_overlap < SLOP_DIST) return;

                const a_mass_prop = arb.mass / (arb.mass + brb.mass);
                const b_mass_prop = brb.mass / (arb.mass + brb.mass);

                // determine over which axis to push
                if (x_overlap < y_overlap) {
                    // if a_x is smaller push a left, b right
                    if (a_x < b_x) {
                        arb.translation.x -= b_mass_prop * a_x;
                        brb.translation.x += a_mass_prop * a_x;
                    } else {
                        arb.translation.x += b_mass_prop * b_x;
                        brb.translation.x -= a_mass_prop * b_x;
                    }
                } else {
                    // if a_y is smaller push a up, b down
                    if (a_y < b_y) {
                        arb.translation.y -= b_mass_prop * a_y;
                        brb.translation.y += a_mass_prop * a_y;
                    } else {
                        arb.translation.y += b_mass_prop * b_y;
                        brb.translation.y -= a_mass_prop * b_y;
                    }
                }
            },
            .Circle => |bcs| {
                _ = bcs;
            },
        },
        .Circle => |acs| switch (bc.shape) {
            .Rectangle => |brs| {
                _ = acs;
                _ = brs;
            },
            .Circle => |bcs| {
                _ = bcs;
            },
        },
    }
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
    from: c.Vector2,
    dir: c.Vector2,
    range: f32,
};

// Hero
pub const Hero = struct {};

// Enemy
pub const Enemy = struct {
    action_state: conf.EnemyState = .idle,
};
