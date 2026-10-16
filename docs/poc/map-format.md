# Trickster map format

Worked out from the client's `data/map` files; implemented in `tools/trickster_map.py`. Each map is four files with the same base name. All integers are little-endian.

## Compression

`.lyr` and `.til` files may be zlib-packed: `u32 magic` (0xC0D0 for `.lyr`, 0xE0F0 for `.til`), `u32 unpacked size`, `u32 packed size`, then zlib data. `.bac` files use the NORI wrapper (bytes `B0 A0`, documented by Libre Trickster's TNT).

## Offset tables

`.lyr` and `.til` start with a table of `u32` offsets. It starts at 0, values increase, and the first non-increasing value ends it. Offsets are relative to the end of the table.

## `.til` tile sets

Each block: `u32 size`, `u32 cols`, `u32 rows`, then `cols × rows` tiles of 32 × 32 pixels. Tiles are stored one after another (each tile contiguous), not as a sheet. Pixels are 16-bit RGB555; `0x7C1F` is transparent.

## `.lyr` layers

Each layer: a 32-byte EUC-KR name, then nine `i32`: type, kind, four unknown values, data size, cols, rows.

| Type | Contents |
|---|---|
| 2 | Tile grid of `cols × rows` `u32` cells, followed by an object list (decals placed on this layer) |
| 0 | Object list only |
| 1 | Picture layer (unused here) |

A tile cell is `tile index | sheet << 16 | flags << 24`. Index `0xFFFF` is empty. Flag bit 0 mirrors the tile horizontally; `0x30` appears on water layers.

An object list is `u32 count`, then 56-byte records: `i32 0, i32 x, i32 y, i32 0`, a 32-byte EUC-KR animation name (matching an animation title in the map's `.bac`), and 8 trailing bytes. Object layer kinds seen: 3 grass, 5 shadows, 6 main props (depth-sorted with actors), 7 effects (drawn on top).

Layers draw in file order: each layer's tiles, then its objects.

## `.md3` grids

Header `MDN_`, version, then 27 `i32`. Fields 7–12 are map width and height in pixels, cell width and height (32), and coarse cols and rows. From offset `0x60`, sections follow: `i32 type, cols, rows, cell w, cell h`, then `cols × rows` bytes.

| Section type | Meaning |
|---|---|
| 1 | Walkability at 16 px: 0 walkable, 1 blocked |
| 3 | Ground type at 16 px (sand, grass, bridge…), likely the `GroundNature` used by drills |
| 4 | Unknown detail values |

## `.bac` objects

A NORI sprite file whose animations are the map's props and decals, referenced by name from the layer object lists.
