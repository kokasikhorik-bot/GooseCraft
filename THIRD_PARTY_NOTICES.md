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

The distributed artifact contains our client and these notices, not the Goose
compiler, TinyCC, Horizon or a Java runtime. Before distributing future graphics,
audio, fonts or native libraries, inventory their actual licenses and include
required notices; do not describe all of Goose's ecosystem as MIT.
