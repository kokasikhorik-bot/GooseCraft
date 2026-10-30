# GooseCraft development

- All gameplay, world state and simulation logic belong in Goose under src/.
- Native C under native/ is limited to platform I/O; formats, paging policy and gameplay remain in Goose.
- Do not launch Minecraft, a JVM or Horizon as a substitute for this client.
- Inspect APIs in the pinned Goose source before using them. Change toolchain.lock.json deliberately.
- Build helpers may use Python; the first launcher uses the Windows built-in cmd.exe.
- Run `python tools/project.py test` for client/core changes. This runs without GUI.
- For renderer changes, also run `python tools/project.py render-test` in the graphics container; preserve GPU readback and window smoke results.
- Keep real test outcomes and unverified platform/GUI assumptions distinct in docs.
- No Minecraft jars, extracted assets, decompiled code, credentials or prepared data in Git.
- Preserve third-party license/copyright notices. Goose is Apache-2.0, Horizon is MIT.
- Keep changes small and commit code and evidence together. Never commit .cache, build or dist.
