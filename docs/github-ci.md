# GitHub: успешный CI GooseCraft 0.11.1 — 2026-10-30

## Повторное использование preflight 0.11.1

[Run 41095302452](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452)
для `7ff602dddcfe93506134f87305f8a929bea16f22` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug graphical clients, UTF-8 PE manifests, 12 suites TinyCC/native release/debug, native-only worker release/debug, bounded fallback reuse, холодный край/teleport, corrupt preflight и dirty-commit failure, stale cache, Unicode I/O/lock, CLI/cmd.exe, benchmark и упаковка |
| ubuntu-22.04 / x64 | success | 12 JIT/native suites и native worker release/debug, кодеки/сохранения/отказы, profiling, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 128 сценариев: прежние 127 плюс файловый fallback с задержкой worker; 38 профилей, 119 PNG, точное gameplay/GCW equality, bounded lifecycle и раздельные счётчики двух источников кеша |

**[Windows ZIP 0.11.1](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452/artifacts/12996891028)**:
`goosecraft-windows-2022-x64-7ff602dddcfe93506134f87305f8a929bea16f22`,
8 843 426 байт. Release graphical/headless клиенты, `.cmd`-лаунчер, лицензии,
документы и BUILD-INFO: 0.11.1, source SHA, formats [1,2,3], generator 1,
profiling schema 1. [Первый запуск](first-play.md), [проверки и парные замеры](fallback-results.md).

SHA-256 ZIP по GitHub API:
`0797d10de9939f8ad9a029408f42192db906efc2aec4aec5083ac13c150151b8`.
Хранение по API до `2027-01-28T17:02:35Z`, если артефакт не удалят раньше.
ZIP локально не скачивался и не хешировался. Для Actions artifact в браузере
может потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452/artifacts/12996411846): 5 444 байта, mesh/stitch без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452/artifacts/12996471462): 5 674 байта.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452/artifacts/12995992222): 1 171 859 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41095302452/artifacts/12996131691): 7 548 432 байта.

[Полные run/jobs/steps/artifacts](validation/github-actions-41095302452.json)
сохранены без credentials. Код проверен как source `7ff602d`; итоговый
docs-only commit с `[skip ci]` меняет только отчёты/evidence и ссылки.
Документы в ZIP отражают момент сборки; текущая ссылка и результаты — здесь.

Дополнительные локальные Linux-проверки: GCC 14.2/12.2, 128 graphics scenarios,
12 парных запусков двух версий с чередованием порядка. На файловом replay
main preparations 30 вместо 38 в 0.11, uncached control — 48. В трёх парах
с искусственными 2 мс медиана wall кадра R 64,5 вместо 81,3 мс; обычный полный
кадр R не ускорился. FPS-прирост и полный RSS/VRAM не заявляются. Startup,
не поместившийся preflight и commit всё ещё могут ждать диск.

Локальная Linux-поставка прошла 680 кадров без доступа к source/Goose compiler,
network=none, UID 1000, 13 fallback reuses при опоздавшем worker; проверены
shutdown/save, exact PNG, неизменность страниц после inspection и 12 лицензий.
Это не проверка скачанного Windows ZIP.

Windows job собрал графику и выполнил native/JIT/CLI, но окно **не открывалось**.
Builder — Windows Server 2022; пользовательская Windows 10/физический GPU
не проверены. UTF-8 argv использует manifest Windows 10 1903+.
Графический CI — Linux Mesa/lavapipe/Xvfb. Сети Java Edition пока нет.

## Фоновая подготовка страниц 0.11 (предыдущая версия)

[Run 41091361216](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216)
для `437bed6259aff94d534bd53eaf7f4d662b1a7c9e` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, прежние 12 suites TinyCC/native release/debug, новый native-only prefetch suite release/debug, TLS JIT rejection, ID 0, stale results/правки, ограниченная очередь, corrupt/fallback, pending shutdown/restart, Unicode I/O/lock, CLI/cmd.exe, benchmark и упаковка |
| ubuntu-22.04 / x64 | success | 12 JIT/native suites и native worker release/debug, кодеки/сохранения/отказы, profiling, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 127 сценариев: прежние 121 плюс synchronous control, файловый контроль, искусственная page/worker latency, pending quit; 37 профилей, PNG/gameplay/GCW equality и bounded lifecycle |

**[Windows ZIP 0.11](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216/artifacts/12993618874)**:
`goosecraft-windows-2022-x64-437bed6259aff94d534bd53eaf7f4d662b1a7c9e`,
7 386 441 байт. Workflow упаковал release graphical/headless клиент,
`.cmd`-лаунчер, лицензии, документы и BUILD-INFO с formats [1,2,3],
generator 1 и profiling schema 1. Миры и debug EXE не предусмотрены упаковкой.
[Первый запуск](first-play.md), [работа worker, измерения и ограничения](prefetch-results.md).

SHA-256 ZIP по GitHub API:
`03a5043515934ec59e5a119721aaec3db5469a7dd96ed44107c9e0e88b7271a5`.
Хранение по API до `2027-01-28T16:36:01Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался. PE manifests извлекались
SDK mt.exe внутри Windows job. Для Actions artifact в браузере может
потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216/artifacts/12994761702): 5 467 байт, mesh/stitch без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216/artifacts/12994547113): 5 655 байт.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216/artifacts/12994237173): 1 168 584 байта.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41091361216/artifacts/12994072585): 6 094 095 байт.

[Полные run/jobs/steps/artifacts](validation/github-actions-41091361216.json)
сохранены без credentials. Формат мира не менялся. Paged-подготовка использует
один Goose worker, staging 8 страниц и очереди limit 1; CPU/GPU/commit остаются
на main. На файловом маршруте main page reads 38 против 48, worker 5; PNG
и GCW совпали. Новые diagnostic delays отмечены в metadata и не выдаются за
измерение реального диска. FPS-прирост, полный RSS/VRAM не подтверждены;
R/fallback и commit по-прежнему могут задержать кадр.

Дополнительная локальная Linux-поставка прошла 30 графических кадров с worker
из /tmp без source/compiler на видимом пути, network=none, UID 1000;
проверены shutdown/save, raw profile и 12 лицензий. Это не Windows ZIP.

Windows job выполнил native worker и прежний native/JIT/CLI, но окно
**не открывалось**. Builder — Windows Server 2022; Windows 10/физический GPU
не проверены. UTF-8 argv использует manifest Windows 10 1903+.
Графический CI — Linux Mesa/lavapipe/Xvfb. Сети Java Edition пока нет.

Проверенный source — `437bed6`. Итоговый docs-only commit с `[skip ci]`
меняет только документы/evidence. Документы внутри ZIP отражают момент сборки;
актуальный итог CI и ссылки находятся в этом файле.

## CPU-пул и страницы мира 0.10 (предыдущая версия)

[Run 41081936076](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076)
для `5bd71bdcba539abade725fe62df23344d53cb1f5` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, 12 suites TinyCC/native release/debug, собственные C sidecars/ABI, Unicode fixed-buffer I/O и lock, CPU/GPU paging, сбои записи/публикации, CRC/ID/coords, GCW v1/v2 vectors, import/export 1/9/81, malformed 1 ГБ, profiling, CLI/cmd.exe, два benchmark и упаковка |
| ubuntu-22.04 / x64 | success | 12 suites, bounded I/O/lock, CPU/GPU paging, codec/отказы, source-preserving import/export, profiling, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 121 сценарий: прежние 111 плюс CPU pages/дальний маршрут/R, window/debug/offscreen, 31 профиль, PNG equality с полным CPU Map, побайтный GCW export и сохранность page files после reopen |

**[Windows ZIP 0.10](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12990900263)**:
`goosecraft-windows-2022-x64-5bd71bdcba539abade725fe62df23344d53cb1f5`,
6 162 727 байт. Workflow упаковал release graphical/headless клиент,
`.cmd`-лаунчер, лицензии, документы и BUILD-INFO с world formats [1,2,3],
generator 1 и profiling schema 1. Миры и debug EXE не предусмотрены упаковкой.
[Первый запуск](first-play.md), [проверки и затраты](paging-results.md),
[формат страниц и перенос](paged-world-format.md).

SHA-256 ZIP по GitHub API:
`2f2bc87c0112b8a5d25c4d1045157203d7652df296ed2e710981dfeadf747004`.
Хранение по API до `2027-01-28T15:34:20Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался. PE manifests извлекались
SDK mt.exe внутри Windows job. Для Actions artifact в браузере может
потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12989512855): 5 459 байт, mesh/stitch без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12989418742): 5 650 байт.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12990027476): 1 066 357 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12990646585): 4 882 154 байта.

[Полные run/jobs/steps/artifacts](validation/github-actions-41081936076.json)
сохранены без credentials. CPU-пул 49 включается отдельно `--paged-world DIR`;
обычные GCW v1/v2 остаются в прежнем backend. Перенос требует нового каталога,
источник не меняется. Новый procedural store хранит seed; импорт без известного
seed сохраняет все страницы явно. Мир остаётся конечным, I/O синхронным.

Подтверждено сокращение блока данных CPU-пула на 128 КиБ для 81-чанкового
мира; общий RSS/VRAM и улучшение FPS не измерены. В локальном idle-прогоне
p50 CPU wall paged оказался выше. Возможны задержки I/O/pop-in; сборщика
старых generations нет. Bulk import/export не ограничен рабочим пулом 49.
Все codec/policy/gameplay — Goose; C содержит только системный I/O.

Windows job проверил native/JIT, собственный C ABI, I/O/lock, manifest и
лаунчер; окно **не открывалось**. Builder — Windows Server 2022;
Windows 10/физический GPU не проверены. UTF-8 argv использует manifest
Windows 10 1903+. Графический CI — Linux Mesa/lavapipe/Xvfb.
Power-loss durability/fault injection не проверялись. Сети Java Edition пока нет.

Проверенный source — `5bd71bd`. Итоговый docs-only commit с `[skip ci]`
меняет только документы/evidence. Документы внутри ZIP отражают момент сборки;
актуальный итог CI и ссылки находятся в этом файле.

## Ограниченный GPU-кеш 0.9 (предыдущая версия)

[Run 41073792518](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518)
для `8978d6ad64a2414d71f35c7ec760423d3496588b` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, 11 suites TinyCC/native release/debug, residency/смена направления/правки вне набора, GCW v1/v2 и восемь world vectors, profiling, Unicode I/O, CLI/cmd.exe, два benchmark и упаковка |
| ubuntu-22.04 / x64 | success | 11 suites, residency/сохранения/векторы, profiling/percentiles, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 111 сценариев: прежние 98 плюс bounded/retained GPU set, eviction/возврат через R, window/debug/offscreen, 23 профиля, равенство PNG/сохранений при одинаковой области рисования |

**[Windows ZIP 0.9](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518/artifacts/12986208060)**:
`goosecraft-windows-2022-x64-8978d6ad64a2414d71f35c7ec760423d3496588b`,
4 993 903 байта. Workflow упаковал release graphical/headless клиент,
`.cmd`-лаунчер, лицензии, документы и BUILD-INFO с world formats [1,2],
generator 1 и profiling schema 1. Миры и debug EXE не предусмотрены упаковкой.
[Первый запуск](first-play.md), [кеш, замеры и ограничения](residency-results.md).

SHA-256 ZIP по GitHub API:
`ceb68c27e366ff6a82575a7121809e95def6dbb299b0f933b67ad50d467042c8`.
Хранение по API до `2027-01-28T14:41:05Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался. PE manifests извлекались
SDK mt.exe внутри Windows job. Для Actions artifact в браузере может
потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518/artifacts/12985953433): 5 460 байт, mesh/stitch без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518/artifacts/12986836504): 5 691 байт.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518/artifacts/12986058377): 922 946 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41073792518/artifacts/12985009975): 3 747 993 байта.

[Полные run/jobs/steps/artifacts](validation/github-actions-41073792518.json)
сохранены без credentials. В обычной игре GPU-кеш ограничен 25 мешами;
данные всех 81 CPU-чанка остаются в памяти. GCW v1/v2 и генератор 1 не менялись.
Подтверждена экономия запрошенной live mesh capacity; в одном idle-прогоне
p50 wall не улучшился. Общая VRAM/RSS, GPU timestamps и преимущество над
Minecraft не измерены. После смены области возможен pop-in, она ограничена
по границам чанков. Сети Java Edition пока нет.

Windows job проверил native/JIT, файловое I/O, manifest и лаунчер, окно
**не открывалось**. Builder — Windows Server 2022; Windows 10/физический GPU
не проверены. UTF-8 argv использует manifest Windows 10 1903+.
Графический CI — Linux Mesa/lavapipe/Xvfb, без физических устройств.

Проверенный source — `8978d6a`. Итоговый docs-only commit с `[skip ci]`
меняет только документы/evidence. Документы внутри ZIP отражают момент сборки;
актуальный итог CI и ссылки находятся в этом файле.

## Большой конечный мир 0.8 (предыдущая версия)

[Run 41067598493](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493)
для `8fe4fae2dc7e507d088d3825ff0f2d743707b22c` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, десять suites TinyCC/native release/debug, growable владельцы и независимость copy, GCW v1/v2, дальние стыки/геометрия/движение, восемь независимых world vectors, profiling, Unicode I/O, CLI/cmd.exe, два benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Десять suites, владельцы/GCW v1/v2/world vectors, профиль/процентили, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 98 сценариев: прежние 84 проверки плюс размеры 25/49/81, large window/debug/reference, GCW v2 F5/reopen, far replay за X=32, профили 9/81 чанка |

**[Windows ZIP 0.8](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493/artifacts/12983396786)**:
`goosecraft-windows-2022-x64-8fe4fae2dc7e507d088d3825ff0f2d743707b22c`,
4 037 496 байт. Workflow упаковал release graphical/headless клиент,
`.cmd`-лаунчер, лицензии, документы и BUILD-INFO с world formats [1,2],
generator 1 и profiling schema 1. Миры и debug EXE не предусмотрены упаковкой.
[Первый запуск](first-play.md), [размер, память и проверки](large-world-results.md).

SHA-256 ZIP по GitHub API:
`c23bde253b17acdacf9fb84dfd259cf5fa1cd57fcfed370360b7e5eff52b965a`.
Хранение по API до `2027-01-28T13:57:34Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался. PE manifests извлекались
SDK mt.exe внутри Windows job. Для Actions artifact в браузере может
потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493/artifacts/12983226828): 5 461 байт, mesh/stitch без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493/artifacts/12983576378): 5 654 байта.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493/artifacts/12984315802): 792 511 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41067598493/artifacts/12983646262): 2 796 460 байт.

[Полные run/jobs/steps/artifacts](validation/github-actions-41067598493.json)
сохранены без credentials. Новые обычные миры имеют 81 чанк, старые сохраняют
размер; GCW v1 не мигрирует автоматически. Все чанки и меши пока резидентны.
Сети Minecraft Java Edition ещё нет; преимущество над Minecraft не измерено.

Windows job проверил native/JIT, файловое I/O, manifest и лаунчер, окно
**не открывалось**. Builder — Windows Server 2022; Windows 10/физический GPU
ещё не проверены. UTF-8 argv использует manifest Windows 10 1903+.
Графический CI — Linux Mesa/lavapipe/Xvfb, без физических устройств.
Профили измеряют CPU wall с ожиданиями, без GPU timestamps/FPS/RSS totals.

Проверенный source — `8fe4fae`. Итоговый docs-only commit с `[skip ci]`
меняет только документы/evidence. Документы внутри ZIP отражают момент сборки;
актуальный итог CI и ссылки находятся в этом файле.

## Профилирование 0.7 (предыдущая версия)

[Run 41059622515](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515)
для `f8e6576a07c191fcaa61dfe9960c6bdcb3282d56` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, девять suites TinyCC/native release/debug, profile ring/summary/I/O, независимые процентили, world vectors, CLI/cmd.exe, два benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Девять suites, profiling JSON/percentiles, сохранения, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 84 сценария: прежние проверки плюс девять профилей, PNG/gameplay equivalence при profiling, rollover/warmup/F5/pause, отсутствие незапрошенного readback, сохранение мира перед ошибкой profile export |

**[Windows ZIP 0.7](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515/artifacts/12978751839)**:
`goosecraft-windows-2022-x64-f8e6576a07c191fcaa61dfe9960c6bdcb3282d56`,
3 194 317 байт. Workflow упаковал release графического/headless клиента,
`.cmd`-лаунчер, лицензии, документацию и BUILD-INFO с profiling schema 1.
Сохранения и debug EXE не предусмотрены упаковкой. [Первый запуск](first-play.md),
[как собрать профиль](profiling.md), [замеры и ограничения](profiling-results.md).

SHA-256 ZIP по GitHub API:
`0ce89bc8ec355666b0c2391ef07daf885bb056ee87ecb1d1740ff9e6ee0fcd0c`.
Хранение по API до `2027-01-28T13:00:05Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался. PE manifests извлекались
SDK mt.exe внутри Windows job. Для Actions artifact в браузере может
потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515/artifacts/12979215374): 5 444 байта, CPU mesh/stitch, без GUI.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515/artifacts/12978033990): 5 699 байт.
- [Graphics/profile evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515/artifacts/12977254212): 625 895 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41059622515/artifacts/12978068997): 1 955 749 байт.

[Полные run/jobs/steps/artifacts](validation/github-actions-41059622515.json)
сохранены без credentials. На Windows проверены кодек/статистика профиля и
файловое I/O; окно **не открывалось**, кадровые измерения Windows GPU отсутствуют.
Графические samples относятся к Linux lavapipe/Xvfb. `wall_ns` — время
CPU-цикла с ожиданиями, не GPU timestamp или доказанный FPS; offscreen
может долго завершать очередь при tail flush. Полная RAM/VRAM не измерена.

Пользовательская Windows 10/физический GPU ещё не проверены. UTF-8 argv
использует Windows 10 1903+ manifest. Пользователю не нужны локальные
инструменты разработки. GCW v1, размер мира и отсутствие сети Java Edition
сохранены. Проверенный source — `f8e6576`; итоговый docs-only commit с
`[skip ci]` обновляет только документы/evidence. Документы внутри ZIP
отражают момент сборки, актуальный итог CI находится в этом файле.

## Согласование рёбер 0.6.1 (предыдущая версия)

[Run 41053468183](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183)
для `91889884ff1a90242bcb10158b115f8be57f853e` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 PE manifests, восемь suites TinyCC/native release/debug, triangle coverage/T-стыки, Unicode I/O, четыре terrain SHA-256 vectors, CLI/cmd.exe, два benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Восемь suites, сохранения и terrain vectors, CLI, оба benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 75 сценариев, 16 обзоров рельефа без замкнутых clear-пикселей, shared color edges, raw control обоих старых просветов, window/debug, replay, culling, dirty и saves |

**[Windows ZIP 0.6.1](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183/artifacts/12976740022)**:
`goosecraft-windows-2022-x64-91889884ff1a90242bcb10158b115f8be57f853e`,
2 521 015 байт. Workflow упаковал release-клиент, headless-клиент, `.cmd`,
лицензии, документацию и BUILD-INFO. Debug EXE/пользовательские миры не
предусмотрены упаковкой. [Первый запуск](first-play.md),
[результаты и цена исправления](stitch-results.md).

SHA-256 ZIP по API:
`750b7f5078a2caa4553770c48ea811a43dd250f15adc51eea40c8d969de8233e`.
Хранение по API до `2027-01-28T12:11:19Z`, если артефакт не удалят раньше.
Windows ZIP локально не скачивался и не хешировался: размер/digest взяты
из metadata. PE manifests проверены SDK mt.exe внутри Windows job.
Для скачивания Actions artifact в браузере может потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183/artifacts/12976411262): 5 477 байт, mesh + stitch reports.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183/artifacts/12976076158): 5 672 байта.
- [Graphics evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183/artifacts/12976545253): 559 915 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41053468183/artifacts/12975741715): 1 290 229 байт.

[Run/jobs/steps/artifacts](validation/github-actions-41053468183.json)
сохранены без credentials. Исправление не меняет GCW v1/seed и игровые правила.
У рельефа 158 944 полезных mesh-байта против 71 896 raw / 589 424 reference.
Цена CPU-построения на локальных GCC выросла на 27–30% относительно raw;
это исправление корректности, преимущество FPS над Minecraft не измерено.
На границах граней допускаются небольшие расхождения цвета с reference,
точная попиксельная эквивалентность рельефа не заявляется.

Windows GUI **не открывалось**. Builder — Windows Server 2022, не пользовательская
Windows 10; физический GPU/реальные мышь и клавиатура не проверены. UTF-8 argv
использует Windows 10 1903+ manifest. Пользователю не нужны Goose/Python/Java
или инструменты сборки. Текущий мир всё ещё 48×16×48, без сети Java Edition.

Итоговый docs-only commit с `[skip ci]` сохраняет отчёт и ссылки; проверенный
код остаётся от `9188988`. Документы внутри ZIP отражают момент сборки,
актуальный итог CI находится в этом файле.

## Рельеф 0.6 (предыдущая версия)

[Run 41040892876](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876)
для `958076edf3fb97aba3eea2733bc6ffe2eaa5ffc9` завершился **success**.

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, UTF-8 manifests через SDK mt.exe, семь suites TinyCC/native release/debug, четыре SHA-256 terrain vectors, Unicode saves, CLI/cmd.exe launcher, benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Семь suites, четыре terrain vectors, сохранение/ошибки, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 40 сценариев: старые single/multi/seams, рельеф, другой seed, traversal/edit/jump, release/debug/window/offscreen, culling и persistence |

**[Windows ZIP 0.6](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876/artifacts/12969759287)**:
`goosecraft-windows-2022-x64-958076edf3fb97aba3eea2733bc6ffe2eaa5ffc9`,
1 904 581 байт. В поставке release-клиент, headless-клиент, `.cmd`-лаунчер,
лицензии, документация и BUILD-INFO (версия, source SHA, CI URL, версия
формата мира и генератора). Сохранения и debug EXE не включены.
[Первый запуск](first-play.md), [результаты 0.6](terrain-results.md).

API сообщил SHA-256 ZIP:
`246931ca20aeb157b04b064bd618460dff0ae32eaf7bf9722a5d20116200a25a`.
Срок хранения по API: `2027-01-28T10:27:31Z`, если артефакт не удалят раньше.
Размер/digest — метаданные GitHub; Windows ZIP локально не скачивался и не
хешировался. Для скачивания в браузере может потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876/artifacts/12971100082): 2 511 байт.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876/artifacts/12969049300): 2 528 байт.
- [Graphics evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876/artifacts/12970860562): 206 893 байта.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41040892876/artifacts/12969434033): 676 267 байт.

[Полные run/jobs/steps/artifacts](validation/github-actions-41040892876.json)
сохранены без credentials. PE manifest проверен внутри Windows job,
действительные Unicode argv/I/O проверены native-клиентами. Само окно
на Windows Server 2022/Windows 10 **не открывалось**. Минимум для UTF-8
activeCodePage — Windows 10 1903+; пользователю инструменты сборки не нужны.

Новый мир по seed 12345, прежний GCW v1 читается без перегенерации. В обзорном
кадре Linux lavapipe известны два одиночных просвета greedy-меша; GPU
эквивалентность reference для рельефа не заявляется. Сырые различия и PNG
сохранены, прежние строгие сравнения плоских сцен сохранены.
Подробности и следующий шаг исправления — [в отчёте](terrain-results.md).

Итоговый docs-only commit с `[skip ci]` меняет только документацию/evidence,
проверенные исходники остаются от `958076e`. Документы внутри ZIP отражают
момент сборки; актуальные ссылки и итог CI находятся в этом отчёте.

## Несколько чанков 0.5 (предыдущая версия)

[Run 41034821463](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463)
для `5f4a14cc007e916969cf4db689f05304b7b9a19a` завершился **success**.
Все три jobs прошли:

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графики, встраивание/извлечение UTF-8 PE manifest, шесть headless suites в TinyCC/native и release/debug, настоящие Unicode save I/O, CLI/launcher, benchmark, упаковка |
| ubuntu-22.04 / x64 | success | Шесть suites, сохранение/ошибки/CRC, CLI, benchmark и упаковка |
| Linux / software Vulkan and X11 | success | 30 сценариев: single/multi/seams, dirty-бюджет, culling, manual/exit save и reopen, default profile, reference/debug |

**[Windows ZIP 0.5](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463/artifacts/12967826992)**:
`goosecraft-windows-2022-x64-5f4a14cc007e916969cf4db689f05304b7b9a19a`,
1 663 815 байт. Содержит release графического и headless клиентов, `.cmd`,
лицензии, документацию и `BUILD-INFO.json` (версия, source SHA, CI URL).
Debug/benchmark EXE и пользовательские миры в поставку не включаются.
[Инструкция](first-play.md), [результаты 0.5](multichunk-results.md).

API сообщил SHA-256 ZIP:
`461dbbb075396c5df74f742a971bc9e2109290dfb3b536a5c7f8b6b2774eac72`.
По API срок хранения — до `2027-01-28T09:37:47Z`, если артефакт не удалят раньше.
Digest и размер взяты из API; ZIP локально не скачивался и не хешировался.
PE manifest проверен SDK mt.exe внутри Windows job, не по скачанному архиву
на Linux. Для Actions artifact через браузер может потребоваться вход в GitHub.

Другие artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463/artifacts/12968241070): 2 513 байт.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463/artifacts/12968365537): 2 543 байта.
- [Graphics PNG/JSON evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463/artifacts/12966879850): 123 357 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41034821463/artifacts/12968435285): 439 865 байт.

[Полные run/jobs/steps/artifacts](validation/github-actions-41034821463.json)
сохранены без credentials. Кириллица проверена на настоящих файлах и в native
argv после manifest, а не только внутри JIT. F5/закрытие окна и default profile
проверены на Linux/Xvfb; графический Windows EXE выполнялся только с `--help`,
неверными аргументами и отказом загрузки повреждённого файла до GPU.
**Windows GUI и пользовательская Windows 10 ещё не проверены.**

UTF-8 activeCodePage требует Windows 10 1903+; SDK нужен только облачному
builder, пользователю локальные инструменты не нужны. Мир пока фиксированный
48×16×48, без сети и совместимости Java Edition. Итоговый docs-only commit
с `[skip ci]` не меняет проверенные исходники. Документы внутри ZIP отражают
момент сборки; актуальный итог CI публикуется в этом отчёте.

### История первых Windows-запусков 0.5

Первый [run 41031858534](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41031858534)
для `5d3536ca4ccf54f3bba7f7f9c542b352908f4ba9` прошёл оба Linux jobs,
включая 30 графических сценариев. Windows собрал release/debug графики,
но остановился на core/seam/save tests; benchmark и ZIP на Windows не создавались.
[Метаданные](validation/github-actions-41031858534.json).

Annotations сообщили только `Process completed with exit code 1`. Полный job log
не удалось скачать через текущую сеть (URLError на скачивании, signed URL и
Authorization не сохранялись). Поэтому конкретная трассировка Windows здесь
не выдумывается. Независимо воспроизведён дефект Python-логирования при
`PYTHONIOENCODING=cp1252`: вывод пути `миры` падает с UnicodeEncodeError до
начала storage test. [До](validation/multichunk/cp1252-before.log) и
[после](validation/multichunk/cp1252-fixed.log): с явной настройкой UTF-8 весь
набор проходит при той же исходной cp1252.

Workflow явно задаёт `PYTHONUTF8=1`/`PYTHONIOENCODING=utf-8`, entry point helper
настраивает stdout/stderr в UTF-8. При неожиданном отказе helper публикует
экранированную аннотацию с traceback и последними сообщениями дочернего процесса.
Игровой Goose-код, формат сохранения и тесты кириллицы не упрощались.
Это промежуточное исправление само по себе ещё не давало успешного Windows run.

Повтор [41033278248](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41033278248)
также прошёл оба Linux jobs. Новая диагностика дала точную Windows-ошибку:
TinyCC storage test прошёл, а `storage-tests.exe` остановился на первом
`storage::save`, tests/storage.goose:38. [Аннотации](validation/github-actions-41033278248-annotations.json),
[jobs/steps](validation/github-actions-41033278248.json). Настройка Python UTF-8
устраняет отдельный воспроизведённый дефект логирования, но её недостаточно
для нативного argv приложения.

Проверены pinned `runtime_os.h:gs_os_arg`, `build.h` и CMakeLists.txt Goose:
native `main(argc,char** argv)` получает ANSI argv, из которого кириллица уже
потеряна; compiler/JIT содержит свой UTF-8 activeCodePage manifest.
Нативная команда Goose build не переносит этот manifest в наши программы.
Добавлен собственный `resources/windows/GooseCraft.manifest`, встраиваемый
Windows SDK mt.exe во все наши AOT EXE до их запуска. Helper извлекает PE
manifest обратно и проверяет `activeCodePage=UTF-8`. Upstream не патчится,
запись мира остаётся на Goose и исходные Unicode I/O тесты выполняются полностью.
Следующий run 41034821463, приведённый выше, подтвердил manifest и успешные
native Unicode I/O тесты. Game/format код и сами Unicode tests не упрощались.

## История: успешный CI 0.4 — 2026-10-30

## Оптимизация 0.4

[Run 41022704811](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811)
для `e4c49678cc65f014425ba2fc8923ce08dacea703` завершился **success**.
Все три jobs прошли на GitHub-hosted runners:

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графического клиента, TinyCC/native core/mesh/player в release/debug, CLI, реальный cmd.exe-лаунчер, native benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Headless core/mesh/player, CLI, native benchmark и упаковка |
| Linux / software Vulkan and X11 | success | Закреплённый Docker, 14 графических сценариев без сети, проверка поверхности/изображения, кеширования и GPU capacity |

**[Windows ZIP 0.4](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962646663)**:
`goosecraft-windows-2022-x64-e4c49678cc65f014425ba2fc8923ce08dacea703`,
1 468 368 байт. Содержит release `goosecraft-client.exe`, headless-клиент,
`goosecraft.cmd`, документацию и лицензии. Debug EXE и benchmark EXE в поставку
не включаются. [Первый запуск](first-play.md).

GitHub API сообщил digest ZIP:
`sha256:69d3136d17978e63a15a7602fba6b69f97d808d488c5e472de6b3cf4fd1157df`.
По API срок хранения — до `2027-01-28T07:51:59Z`, если артефакт не удалят раньше.
ZIP в этой сессии не скачивался; digest не пересчитан локально. Ранее proxy
блокировал redirect на Actions storage, это ограничение описано в истории.
Наличие и размер подтверждены API; `.exe` выполнялись непосредственно в Windows job.
Для скачивания Actions artifact может потребоваться вход в GitHub.

Отдельные artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962860898): 2 505 байт.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962153282): 2 540 байт.
- [Graphics evidence PNG/JSON](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962721280): 58 613 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962651528): 268 517 байт.

Полные [run/jobs/steps/artifacts](validation/github-actions-41022704811.json)
сохранены без заголовков авторизации и credentials. Windows benchmark выполнился,
но его численные результаты здесь не цитируются: artifact внутрь облака не
скачивался. Таблица CPU-времени в [optimization-1.md](optimization-1.md) относится
к отдельным локальным облачным Linux GCC 14.2/12.2 замерам.

Границы: Windows job запускал графический EXE для `--help` и ошибочных аргументов;
окно на Windows и пользовательская Windows 10 не проверены. Linux replay
использует SDL/gfx-инъекцию ввода, не физические устройства. Между optimized
window/offscreen/debug проверяется точное совпадение PNG и состояния. Между
greedy/reference поверхность точна, но растеризация полного replay имеет два
граничных пикселя разницы; тест допускает максимум четыре, строго вне HUD,
только на общей границе фон/геометрия. Это не заявление о побайтно одинаковой
картинке со старым мешером или более высоком полном FPS, чем Minecraft.

Итоговая документация отправляется отдельным docs-only commit с `[skip ci]`;
исходники и workflow после успешного run не меняются. Документы в ZIP отражают
состояние на момент сборки, актуальный итог CI находится в этом отчёте.

## История: успешный игровой прототип 0.3 — 2026-10-30

## Игровой цикл 0.3

[Run 41015539670](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670)
для commit `27f31391bf5c9951d2d10d5d2c275869f557c999` завершился **success**.
Это исходники первого игрового цикла: WASD/мышь, прыжок, коллизии, выбор,
удаление/установка блока, перестроение меша, HUD и пауза.

| Job | Результат | Проверенное поведение |
| --- | --- | --- |
| windows-2022 / x64 | success | Компилятор Goose, release/debug графического клиента, TinyCC/native core/mesh/player в release/debug, CLI, настоящий cmd.exe-лаунчер и упаковка |
| ubuntu-22.04 / x64 | success | Компилятор, headless core/mesh/player в четырёх режимах, CLI и упаковка |
| Linux / software Vulkan and X11 | success | Graphics Docker из закреплённых исходников, десять render/input сценариев без сети, включая игру в Xvfb и совпадение release/debug/window/offscreen |

**Новый [Windows ZIP 0.3](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12959044218)**:
`goosecraft-windows-2022-x64-27f31391bf5c9951d2d10d5d2c275869f557c999`,
1 372 675 байт. Включает release `goosecraft-client.exe`, `goosecraft-headless.exe`,
`goosecraft.cmd`, документацию и лицензии. Debug EXE не включён в поставку.
GitHub API сообщил SHA-256 ZIP:
`eb0544d4f04f3ae7cbc1ab20ab4984d00a1b38e8314b351eba9585a0619786ee`.
Для скачивания Actions artifact через браузер может потребоваться вход в GitHub.
[Инструкция первого запуска](first-play.md).

Также созданы [Linux headless ZIP](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12958964279)
(176 360 байт) и [PNG/JSON/Vulkan evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12959672378)
(40 588 байт). [Полные метаданные API](validation/github-actions-41015539670.json)
содержат tested SHA, jobs/steps и artifacts; credentials не включены.

Границы проверки: Windows job открыл графический EXE только для `--help`
и ошибочных аргументов, окно не запускалось. Реальный графический запуск
подтверждён на Linux software Vulkan/X11 в Xvfb. Replay использует инъекцию
событий SDL/gfx и фиксированное время; физические устройства ввода он не
проверяет. Пользовательская Windows 10, её Direct3D/GPU driver и GUI ещё
не проверены. Это первый кандидат для такого локального теста.

Новый ZIP в Codex Cloud не скачивался: размер и digest здесь получены от API,
а не пересчитаны по локальному архиву. Предыдущее скачивание Actions ZIP
было заблокировано proxy на redirect storage (описано ниже). Проверки `.exe`
выполнены непосредственно в Windows job.

Отчёт после успешного run сохраняется отдельным docs-only commit с `[skip ci]`.
Проверенные исходники и workflow при этом не меняются. Сопроводительные документы
в ZIP соответствуют состоянию на момент сборки; итог CI публикуется здесь.

## История: графическая основа 0.2 — 2026-10-30

Репозиторий [kokasikhorik-bot/GooseCraft](https://github.com/kokasikhorik-bot/GooseCraft)
сделан публичным по явному решению владельца. Доступ без авторизации проверен:
GitHub возвращает HTTP 200. `origin` содержит обычный HTTPS URL без токена.
Настройки оплаты аккаунта не менялись.

## Подтверждённая сборка

[Native builds and rendering, run 41010605234](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234)
для commit `d21220f887a9b710b0e02c7c5ac3be3d8bcfbc7a` завершился **success**.
Все три jobs выполнились на GitHub-hosted runners:

| Job | Результат | Проверенное поведение |
| --- | --- | --- |
| windows-2022 / x64 | success | Сборка Goose и обоих клиентов, TinyCC/native core/mesh в release/debug, CLI, настоящий cmd.exe-лаунчер, упаковка |
| ubuntu-22.04 / x64 | success | Сборка Goose, headless core/mesh и CLI, упаковка |
| Linux / software Vulkan and X11 | success | Сборка закреплённого graphics-контейнера, Vulkan CPU device, пустая/voxel-сцена и X11-окно в Xvfb с отключённой сетью |

Windows smoke-тесты проверили отсутствующий бинарник (exit 3), передачу аргументов
и результат симуляции, ошибочные аргументы каждого клиента (exit 2), пути с
пробелами, другой рабочий каталог и выбор графического клиента через `--help`.
Графический Windows-процесс выполнял только `--help` и ошибочные аргументы;
окно на Windows **не открывалось**. Пользовательская Windows 10, её видеодрайвер
и игровое управление ещё не проверены.

Linux render-test проверил GPU readback, отсутствие геометрии в пустом кадре,
наличие геометрии в voxel-кадре и побайтное совпадение PNG между offscreen и
оконным режимом. Успех этой проверки не считается проверкой Windows GUI.

Полные нормализованные метаданные runs/jobs/steps и artifacts:
[github-actions-41010605234.json](validation/github-actions-41010605234.json).
Секреты и заголовки авторизации в отчёт не включены.

## Артефакты

- [Windows x64](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234/artifacts/12957815526):
  `goosecraft-windows-2022-x64-d21220f887a9b710b0e02c7c5ac3be3d8bcfbc7a`,
  1 290 170 байт. Упаковка включает `goosecraft-client.exe`, `goosecraft-headless.exe`,
  `goosecraft.cmd`, документацию и лицензионные уведомления.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234/artifacts/12956729264):
  114 525 байт.
- [Графические доказательства](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234/artifacts/12957312102):
  PNG/JSON/Vulkan report, 8 504 байта.

GitHub API сообщил SHA-256 Windows ZIP:
`172eb30b6b7d5bc1608802f1fd10b860ec0f394aa9b649806329e3003c41d09c`.
Артефакт хранится до `2027-01-28T05:50:00Z` согласно API, если его не удалят раньше.
Для скачивания Actions artifacts через браузер может потребоваться вход в GitHub.

Скачать ZIP внутрь Codex Cloud не удалось: HTTP proxy вернул 403 для redirect
на хранилище GitHub. Это ограничение скачивания после завершённой сборки.
Наличие, размер и digest подтверждены API; SHA-256 здесь не пересчитан по локально
скачанному архиву, PE-файлы отдельно на облачном Linux не инспектировались.
Проверки запуска `.exe` выполнены именно Windows job.

## Исправления, необходимые для первого Windows CI

1. Официальный manifest actions/python-versions содержит Python 3.12.14 для Linux,
   но не для Windows 2022. Первый публичный run
   [41009915165](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41009915165)
   прошёл Linux jobs, а Windows остановился на setup-python. Matrix теперь
   закрепляет Linux Python 3.12.14 и Windows Python 3.12.10; доступность обеих
   версий проверена по официальному manifest. [Метаданные](validation/github-actions-41009915165.json).
2. Smoke-тест ошибочного вызова лаунчера выполнялся до копирования графического
   бинарника в тестовую папку. Вызовы разделены по маршрутам: headless проверяется
   с `--headless`, графический — после копирования `goosecraft-client.exe`.
   Оба маршрута проверены финальным Windows job.

Игровая логика, Goose compiler pin и версии SDL/Nuklear не менялись.
Документационное обновление итогов отправляется с `[skip ci]`: оно не меняет
проверенные исходники или workflow и не повторяет уже прошедшую сборку.

## История приватного запуска

2026-10-29 репозиторий был создан приватным. Первый push запустил
[40947702634](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/40947702634)
для `1b83739d375ccb71875e515632d956485e69ae58`, но ни одному job не выделили runner.
Аннотация GitHub:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

Шагов и артефактов в том запуске было 0.
[Исходные метаданные](validation/github-actions-40947702634.json) сохранены как
история; эта блокировка не относится к успешному публичному run, приведённому выше.
