// C cubiomes bindings — only used in parity tests, never in production.
// Links against the actual C cubiomes library for differential testing.
pub const c = @cImport({
    @cInclude("biomes.h");
    @cInclude("generator.h");
    @cInclude("finders.h");
});
pub usingnamespace c;
