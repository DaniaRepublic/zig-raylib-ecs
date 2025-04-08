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
pub const Collider = struct {
    bounding_rect: c.Rectangle,
};

// Drawable
pub const Drawable = struct {
    hidden: bool = false,
    tex_name: conf.TextureAssets,
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
