# 🎭 vaudeville

Gives the frontmost macOS window **the hook**: a brass vaudeville crook slides in
from the wings, waggles menacingly, and yanks the window offstage — then heavy
velvet theatre curtains drop across the screen (with a bounce, a thud, and an
INTERMISSION card), rise again, and the window glides back to its seat.

Everything is drawn and synthesized procedurally — no image or sound assets.

[!vaudeville.gif]()

## Run it

```bash
devbox run show
```

Or build once and trigger it however you like (hotkey app, Raycast, `cron`, a
git hook for when CI fails…):

```bash
devbox run build
./.build/release/vaudeville --delay 2   # two seconds to front the victim window
```

### Options

| Flag | Effect |
| --- | --- |
| `--delay <s>` | wait before the show starts |
| `--curtains-only` | no hook, just the curtain drop/rise |
| `--silent` | no slide whistle, whoosh, or thud |
| `--no-restore` | leave the yanked window in the wings |
| `--text <s>` | curtain text (default `INTERMISSION`, `""` for none) |
| `--preview [dir]` | render `hook.png` + `curtain.png` and exit (no GUI) |

## Install as an app (Spotlight)

```bash
devbox run package
cp -R dist/Vaudeville.app /Applications/
```

Then **⌘Space → "Vaudeville" → return** whenever a window deserves the hook.
The bundle is `LSUIElement` (no Dock icon, never steals focus), so the window
you were just using is the one that gets yanked; a 0.75 s default delay lets
the Spotlight panel get offstage first. The app icon — the curtain with the
hook across it — is rendered by the app itself (`--render-icon`) and packed
into an `.icns` by [scripts/package.sh](scripts/package.sh), which also ad-hoc
signs the bundle. As an app it requests its own Accessibility permission
("Vaudeville" in the list), separate from your terminal's.

## Permission

Dragging someone else's window uses the Accessibility API. Grant your terminal
access under **System Settings → Privacy & Security → Accessibility** (the app
prompts on first run). Without it the show still goes on: the hook mimes the
grab and the curtains fall regardless.

## How it works

- **[AXTarget.swift](Sources/vaudeville/AXTarget.swift)** — finds the frontmost
  app's focused window via `AXUIElement` and moves it by setting
  `kAXPositionAttribute` at ~60 Hz (windows can't be animated by another
  process any other way).
- **[Hook.swift](Sources/vaudeville/Hook.swift)** — the crook is a parametric
  polyline (pole + 90°→322° sweep) stroked three times (outline, brass, gleam)
  as `CAShapeLayer`s on a transparent, click-through, screen-saver-level
  overlay window.
- **[Curtain.swift](Sources/vaudeville/Curtain.swift)** — velvet rendered
  per-pixel: a phase-wobbled sine gives the folds, lit from above, with a gold
  braid band and hanging fringe along the hem.
- **[Director.swift](Sources/vaudeville/Director.swift)** — a phase timeline at
  120 Hz keeps the layer animation and the AX window moves in lockstep. The
  yank uses an ease-in-back (wind-up, then the snatch); the curtain lands on an
  ease-out-bounce.
- **[Orchestra.swift](Sources/vaudeville/Orchestra.swift)** — the descending
  slide whistle, fabric whoosh, and landing thud are synthesized into PCM
  buffers (`AVAudioEngine`); the thud is scheduled for the bounce's first
  floor-contact at `t = 1/2.75` of the drop.

Interrupting mid-show (Ctrl-C) restores the victim window before exiting.

## Toolchain

Managed with [devbox](https://www.jetify.com/docs/devbox/): `devbox run
build | show | preview | clean`. The only dependency is the Swift toolchain,
which on macOS must come from the Xcode Command Line Tools (`xcode-select
--install`) — the nixpkgs Swift isn't viable on arm64 macOS, so `packages` is
deliberately empty and the scripts unset the nix `SDKROOT`/`DEVELOPER_DIR` so
the system toolchain resolves. Any future portable deps go in via `devbox add`.
