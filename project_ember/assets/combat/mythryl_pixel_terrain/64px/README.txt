2D Pixel Terrain 64px Godot Free
Version 1.0
by Mythryl Studio

2D isometric terrain tileset: grass, cliffs, water, trees, plants and rocks in 4 seasons. 32px and 64px.

HOW THIS PACK WORKS

Isometric terrain at 64px: 64 x 32 tiles. tiles.json has the cell size and the numbering of every set; nature/nature.json has every piece of nature.

GROUND

ground/surfaces has 4 tiles of each surface; any joins any, so mix them freely. ground/edges has corner sets: 16 tiles laying one surface over another, numbered by the corners covered by the second surface (north, the top point, 1; east 2; south 4; west 8). Lay the surfaces on the corners of your map, then each cell takes the tile its four corners make. Keep paths a cell clear of water: coasts come with plain land.

CLIFFS

cliffs has a block of crags with a grass top that raises a cell 39 px. It fills its cell from the ground up: draw it with its bottom on the cell's bottom, like any tile, and stack blocks for taller cliffs, each one step higher. The -sides folder has the same block without a top, to lay any ground tile on. Draw cells back to front.

WATER

water has shallow water and coasts (land beside water), animated: each tile is frame 0, and water/animated has its 12 frames as a strip, played at 8 fps. Coasts are numbered by the neighbours that are water, added up; tiles.json lists the neighbours' numbers.

NATURE

nature has a folder per piece, in four turns, each image with its shadow. Every image of a piece is the same size with its pivot (where it stands) on the same pixel, given in nature.json. nature/sheets has each piece on one sheet, a row per look and a column per turn.

GODOT 4

The godot folder has a TileSet per ground with a corner terrain set, one per coast land with a terrain set of land and shallow water (animated), and one of cliff blocks, each block centred on its cell. Paint terrains with the TileMap terrain tools. Put each height of cliffs on a TileMapLayer of its own, raised by the block's step. Every piece of nature has SpriteFrames (an animation per look, a frame per turn) for it and its shadow, and a scene with both on its pivot: set the animation and frame on both. example.tscn lays the valley.

All images are PNG with transparency. Scale by whole numbers
(2x, 3x, 4x) with nearest-neighbour filtering to keep pixels crisp.

This is the free edition. The full pack is available at
https://mythrylstudio.itch.io/pixel-terrain

LICENCE

See LICENSE.txt. In short: use these in your own commercial or
non-commercial projects, edited or not. Do not resell or share the
files themselves. Credit is appreciated but not required.

UPDATES

This pack may receive future updates with content as it becomes
available, and everyone who has it will receive the new assets.

Made something with these, or have an idea for the pack? Tell me:
https://mythryl.com
