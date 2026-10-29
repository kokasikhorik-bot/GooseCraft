# Third-party notices

Original GooseCraft code is MIT (LICENSE). Dependencies retain their own licenses.
No Minecraft/Mojang/Microsoft code, jars, extracted data, textures, sounds or fonts
are included. The 16³ fixture and numeric block identifiers are original test data.

| Component | Exact source | Use | License / notice |
| --- | --- | --- | --- |
| Goose compiler, standard library and generated runtime | aardappel/goose at cce94b919d27458856ae2685974049eac78debcf | Compiler is built in the ignored cache. Standard library and runtime are compiled into native programs. Upstream README credits Wouter van Oortmerssen and Claude Fable. | Apache-2.0; full upstream LICENSE in licenses/Goose-Apache-2.0.txt. No upstream NOTICE file found at this revision. |
| TinyCC | third_party/tinycc in that Goose revision | Compiler's in-process test backend; not linked into or shipped with our native client. | LGPL-2.1, licenses/TinyCC-LGPL-2.1.txt; individual upstream files retain their notices. |
| cute_spirv / ckit | third_party/cute_spirv in that Goose revision | Built into the compiler, not the headless client. | cute_spirv offers zlib or Unlicense, copyright 2026 Randy Gaul; see the license block in upstream cute_spirv.h. ckit.h carries no separate license block at this revision; do not assume MIT. No compiler binaries are redistributed here. |
| subprocess.h | third_party/subprocess in that Goose revision | Compiler process runner, not our client. | Unlicense; full notice remains at the top of upstream subprocess.h. |
| Horizon | horizon-rust/horizon at 7ebf7d26cbe58d65ef873767c639f144dc403554 | Architectural reference only; no source, binaries or resources incorporated. | MIT, copyright 2026 Ludovic Marie and the Horizon contributors. Upstream notice preserved verbatim in licenses/Horizon-MIT.txt for provenance. |

The stage-1 headless artifact contains our client and these notices, not the Goose
compiler, TinyCC, Horizon or a Java runtime. The stage-2 graphics additions are listed below. Before distributing future graphics,
audio, fonts or native libraries, inventory their actual licenses and include
required notices; do not describe all of Goose's ecosystem as MIT.

## Graphics distribution (stage 2)

The optional graphical client now links goose_gfx and SDL. The independent
headless executable still links neither. The graphics package builds audio/UI
archives as well; this client uses no audio, Nuklear widgets or fonts.
The sources are pinned in toolchain.lock.json, including both submodules.

| Component | Revision / origin | Preserved license |
| --- | --- | --- |
| goose_gfx | 6cfa3dec2ef2a6cb19ee71548b38151094e947bd | Apache-2.0, licenses/GooseGfx-Apache-2.0.txt |
| SDL 3.4.16 | fa2c02bb6e21974a89ea9824bc53c9932abe5f9c | zlib, copyright 1997–2026 Sam Lantinga; licenses/SDL-zlib.txt |
| SDL embedded HIDAPI | SDL src/hidapi | BSD alternative selected, licenses/HIDAPI-BSD.txt |
| SDL embedded yuv2rgb | SDL src/video/yuv2rgb | BSD, copyright 2016 Adrien Descamps; licenses/yuv2rgb-BSD.txt |
| SDL embedded stb_image | SDL src/video/stb_image.h | MIT alternative, copyright 2017 Sean Barrett; licenses/stb-image-MIT-or-Unlicense.txt |
| SDL embedded miniz | SDL src/video/miniz.h | Public domain/Unlicense, Rich Geldreich; licenses/miniz-Unlicense.txt |
| Nuklear | 9f7750296f176e506c2b24ff55bc24495e2db750 | MIT alternative, copyright 2017 Micha Mettke; licenses/Nuklear-MIT-or-Unlicense.txt |
| Nuklear embedded stb | Nuklear nuklear.h | MIT alternative, copyright 2017 Sean Barrett; licenses/Nuklear-stb-MIT.txt |
| Nuklear embedded ProggyClean font | Copyright 2004, 2005 Tristan Grimmer | licenses/ProggyFonts-MIT.txt; no fonts are loaded or rendered by our scene |

The compiler and TinyCC are build tools, not part of the game distribution.
Mesa, Vulkan loader and Xvfb are Linux test-environment packages, not bundled
Windows libraries; their Debian copyright files remain in the container.
The game screenshot is generated from GooseCraft's own geometry/colors; it
contains no Minecraft textures or other Minecraft assets.
