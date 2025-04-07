const std = @import("std");
const c = @import("ray").c;

// config game constants
pub const RESOURCES_BASE_PATH = "./src/resources/";
pub const DARK_GRAY: c.Color = .{ .a = 255, .b = 18, .g = 18, .r = 18 };

/// Enemy state enum
pub const EnemyState = enum {
    idle,
    following_player,
};

/// Keyboard inputs to watch
pub const KbInputs = struct {
    // movement
    a: bool = false,
    d: bool = false,
    w: bool = false,
    s: bool = false,
    // interraction
    e: bool = false,
    l_mouse_down: bool = false,
    l_mouse_pressed: bool = false,
    // modifiers
    l_shift: bool = false,
};

/// Context updated every game loop that can be passed around
pub const GameLoopCtx = struct {
    delta_t: f32,
    mouse_pos: c.Vector2,
    kb_inputs: KbInputs,
};

/// Mechanics
pub const EntityCharacteristics = struct {
    freezable: bool,
    flamable: bool,
    slimable: bool,
    zappable: bool,
    hypnotisable: bool,
};

pub const EntityCharacteristicsState = struct {
    frozen: bool = false,
    flamed: bool = false,
    slimed: bool = false,
    zapped: bool = false,
    hypnotized: bool = false,
};

/// Defines available textures for AssetStorage
pub const TextureAssets = enum {
    hero_default,
    enemy_default,
    gun_default,
    bullet_default,
};

/// Defines available sounds for AssetStorage
pub const SoundAssets = enum {
    gun_default_shot_sound,
    gun_default_hit_dound,
};

pub const AssetStorage = struct {
    textures: std.AutoArrayHashMap(TextureAssets, *c.Texture),
    sounds: std.AutoArrayHashMap(SoundAssets, *c.Sound),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) AssetStorage {
        return AssetStorage{
            .textures = std.AutoArrayHashMap(TextureAssets, *c.Texture).init(alloc),
            .sounds = std.AutoArrayHashMap(SoundAssets, *c.Sound).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *AssetStorage) void {
        const textures = self.textures.values();
        for (textures) |tex| {
            c.UnloadTexture(tex.*);
            self.alloc.destroy(tex);
        }
        const sounds = self.sounds.values();
        for (sounds) |sound| {
            c.UnloadSound(sound.*);
            self.alloc.destroy(sound);
        }
        self.textures.deinit();
        self.sounds.deinit();
    }

    /// return texture if created and added successfully
    pub fn createAddTex(self: *AssetStorage, tex_name: TextureAssets, path: [*]const u8) !*c.Texture {
        const tex = try self.alloc.create(c.Texture);
        tex.* = c.LoadTexture(path);
        self.addTex(tex_name, tex) catch |err| {
            self.alloc.destroy(tex);
            return err;
        };
        return tex;
    }

    pub fn addTex(self: *AssetStorage, tex_name: TextureAssets, tex: *c.Texture) !void {
        self.textures.put(tex_name, tex) catch |err| {
            return err;
        };
    }

    pub fn addSound(self: *AssetStorage, sound_name: SoundAssets, sound: *c.Sound) !void {
        self.sounds.put(sound_name, sound) catch |err| {
            return err;
        };
    }

    pub fn getTex(self: *AssetStorage, tex_name: TextureAssets) ?*c.Texture {
        return self.textures.get(tex_name);
    }

    pub fn getSound(self: *AssetStorage, sound_name: SoundAssets) ?*c.Sound {
        return self.sounds.get(sound_name);
    }
};
