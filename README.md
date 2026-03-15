# boofa-sketch

Continuity Sketch helper — draw on a nearby iPad with Apple Pencil, get the image back as a PNG.

macOS only. Requires macOS 12.0+.

## Install

```bash
brew install wasmir/tap/boofa-sketch
```

## Usage

```bash
boofa-sketch --output-dir /path/to/save --drawing-id <uuid>
```

A Continuity Sketch menu appears. Select your iPad, draw with Apple Pencil, and tap Done.

### Output (stdout JSON)

Success:
```json
{"status":"done","png":"<uuid>.png","width":800,"height":600}
```

Cancelled:
```json
{"status":"cancelled"}
```

Error (stderr):
```json
{"status":"error","message":"..."}
```

## Build from source

```bash
bash scripts/build.sh
```

Produces `boofa-sketch` binary and `BoofaSketch.app` bundle.
