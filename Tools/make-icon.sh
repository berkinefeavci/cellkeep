#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
resource_dir="$repo_root/Sources/ChargeMate/Resources"
iconset_dir="$resource_dir/Assets.xcassets/AppIcon.appiconset"
iconset_tmp="$resource_dir/AppIcon.iconset"
master="$resource_dir/icon-master.png"

mkdir -p "$iconset_dir"
rm -rf "$iconset_tmp"

python3 - "$master" <<'PY'
from PIL import Image, ImageDraw
import sys

output = sys.argv[1]
size = 1024
image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

draw.rounded_rectangle((48, 48, 976, 976), radius=218, fill=(20, 31, 46, 255))
draw.rounded_rectangle((240, 270, 750, 754), radius=66, fill=(232, 242, 250, 255))
draw.rounded_rectangle((750, 430, 798, 594), radius=24, fill=(232, 242, 250, 255))
draw.polygon(((526, 338), (390, 560), (505, 560), (454, 690),
              (616, 452), (496, 452)), fill=(10, 148, 158, 255))

image.save(output, format="PNG")
PY

sips -z 16 16 "$master" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$master" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$master" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$master" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$master" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$master" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$master" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$master" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$master" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$master" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

mkdir -p "$iconset_tmp"
cp "$iconset_dir"/*.png "$iconset_tmp/"
iconutil -c icns "$iconset_tmp" -o "$resource_dir/AppIcon.icns"
rm -rf "$iconset_tmp"
printf 'Generated ChargeMate icon assets in %s\n' "$resource_dir"
