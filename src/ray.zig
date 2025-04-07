//! Not intendet for imports, used as shared module in builds.

pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("raygui.h");
});
