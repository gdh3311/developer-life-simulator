# Desk items

Built-in items (keyboard, mouse, mug, plant) are 3D models built in Blender by `tools/blender/desk_models.py` and rendered to transparent PNGs at twice their on-desk size. The `.glb` models are kept in `content/models/` (ignored by Godot) so they can be reused or edited. The window view is a 3D city rendered for day, dusk and night by `tools/blender/city_window.py` into `content/room/`.

Rebuild everything:

```
blender -b --factory-startup --python tools/blender/desk_models.py -- content/models/desk build/desk_renders
blender -b --factory-startup --python tools/blender/city_window.py -- build/city_renders content/models/room
python tools/blender/finish_desk_assets.py
```

## Decorating mode

The **꾸미기 / Decor** button next to F2 opens decorating mode over the desk view:

- Drag a toy from the tray onto the desk, drag it around, or drag it off the desk (or click it in the tray) to put it away. Up to six toys fit.
- Click the keyboard, mouse, mug or plant to swap it for the next unlocked one; **Change mat** flips through desk mats.
- Locked toys show as silhouettes; hover for what unlocks them. A notice pops up when something you did unlocks a new one.

| Toy | Unlocks with |
|---|---|
| Pen cup, alarm clock | free |
| Debugging duck | your first small ticket |
| Toy robot | delegating to AICode 3 times |
| Lucky cat | achievement "A customer's evening" |
| Launch rocket | achievement "My name on a launch" |
| Gamepad | achievement "Game developer" |
| Perfect-day trophy | achievement "Perfect day" |
| Puzzle cube | 5 small tickets |
| Bonsai | achievement "Specialist" |
| City snow globe | finishing Chapter 5 |

Mats: navy felt (free), cork (Junior), pixel pattern (first merge), RGB (with the RGB keyboard).

`tools/gen_desk_assets.py` still writes the older flat SVGs. They're used only for items that have no render, and `catalog.json` prefers the PNGs listed in `render_sizes.json`.

## Walnut surface

`walnut-surface.png` was made with the built-in ImageGen tool. The room applies its own lighting as the in-game time changes.

> Generate a production-ready game texture for the horizontal surface of a developer's work desk, an uninterrupted single sheet of warm smoke-brown walnut veneer. Wide landscape image around 3:2. Straight overhead orthographic sample, uniform light and even exposure with zero directional shading, material fills the entire frame edge to edge. Rift-sawn fine horizontal wood grain across the width, understated pencil-fine irregular fiber, a few soft brown grain ribbons that read at game scale, satin finish. Deep medium walnut brown with restrained reddish amber undertone. Show only this one material with no plank divisions, no joints, no borders, no shadows, no reflections, no objects, no hardware, no knots or contrasting sapwood, no text, no logos, no gradients. Cohesive hand-painted realistic material for a quiet nighttime narrative indie game, clean from edge to edge. Must accept heavy game-controlled lighting and warm/cool shading over the source texture.

## Add your own item

Put two files in the game's user folder under `desk_assets/` (on Windows: `%APPDATA%\Godot\app_userdata\Developer Life Simulator\desk_assets\`):

`my_keyboard.json`
```json
{ "slot": "keyboard", "name": { "ko": "내 키보드", "en": "My keyboard" }, "image": "my_keyboard.png", "size": [700, 86] }
```
`my_keyboard.png` (or `.svg`)

- `slot`: `keyboard`, `mouse`, `mug` or `plant`
- `size`: on-desk size in pixels. Reference sizes: keyboard 700×86, mouse 150×92, mug 96×80, plant 220×210. Use an image twice that size for sharp results.
- Mugs and plants stand on the desk edge (bottom-center). Keyboards and mice are centered on their spot.

Then open **Dashboard → My desk** and pick it. Custom items are always unlocked.
