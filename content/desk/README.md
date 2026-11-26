# Desk items

Godot renders the wooden worktop, mats, monitor stands and Blender props in one perspective view. The window, monitor and mushroom lamp illuminate the same 3D surfaces. The catalogue uses transparent PNG thumbnails, and custom PNG/SVG props keep their uploaded images.

The window uses `content/models/room/city.glb` and `shaders/city_facade.gdshader`. The shader shades façades and lights office windows based on the game clock. The Blender day, dusk and night renders are available as a fallback.

Rebuild everything:

```
blender -b --factory-startup --python tools/blender/desk_models.py -- content/models/desk build/desk_renders
blender -b --factory-startup --python tools/blender/city_window.py -- build/city_renders content/models/room
python tools/blender/finish_desk_assets.py
```

To rebuild a specific model and its thumbnail, pass its item ID after the directories to `desk_models.py`, then pass the same ID to `finish_desk_assets.py`.

## Decorating mode

Open **Dashboard → My desk → Arrange desk**, or choose **Arrange my desk** in Shoply. For monitor zoom, use the workstation's view control or press **F2**.

- Drag a prop onto the desk, move it with the mouse, or drag it off the desk to put it away. Up to six props fit.
- Select a prop and use **Q / E** or the onscreen arrows to rotate it by 15°. Press **Esc** during a drag to cancel the move.
- Choose a keyboard, mouse, mug, plant, or mat from its category. Walnut, White Studio, and Moss are matching equipment sets.
- Place the mushroom lamp to control its light. The game saves equipment, prop positions and rotation, and the lamp setting.
- Locked props show as silhouettes with a tooltip that says how to unlock them.

| Toy | Unlocks with |
|---|---|
| Pen cup, alarm clock | free |
| Mushroom lamp, field notebook | free |
| Film camera | Junior |
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
