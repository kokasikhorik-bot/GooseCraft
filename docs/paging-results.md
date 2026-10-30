# GooseCraft 0.10 — CPU-пул и страницы

Новый opt-in режим `--paged-world DIR` держит максимум **49 чанков блоков**
в CPU-пуле вместо полного 81-чанкового Map: **200704 вместо 331776 байт**
блоковых данных, на 128 КиБ/39,51% меньше. Это не измерение общего RSS.
GPU-кеш 0.9 сохранён. Кадры и экспорт всех блоков совпали с прежним backend.
Обычный `--world FILE` остаётся прежним; автоматического переноса нет.

![После дальнего CPU-перехода и R: настоящий Linux lavapipe кадр](validation/paging/pages-route.png)

```bat
goosecraft.cmd --paged-world BigPages
goosecraft.cmd --paged-world BigPages --mesh-radius 1
goosecraft.cmd --headless --import-world Old.gcw ImportedPages
goosecraft.cmd --headless --export-pages ImportedPages Backup.gcw
```

Мир конечный, максимум 81 чанк/144×144×16. Каталог формата 3 содержит seed,
generator и индекс, явные страницы нужны только для правок либо импорта.
У импортированного GCW seed неизвестен: все блоки сохраняются явно.
[Спецификация, ошибки и ограничения](paged-world-format.md).

## Архитектура и реальные API

`world::Paged` — фиксированный пул с двусторонним mapping, changed отдельно
от GPU dirty, metadata без всех payload. CPU-область на один чанк шире GPU
для halo; стартовый чанк закреплён для respawn. Все игровые функции общие
через Goose generics: физика, DDA, редактирование, halo, mesh, HUD, renderer.
Отдельной упрощённой игры для paged режима нет.

`pages.goose` реализует binary codec, проверки, seed-generation, выбор пула,
preflight, checkpoint и импорт/экспорт. Commit сначала пишет новые immutable
generation-pages, затем атомарно меняет индекс. Ошибка записи не очищает
живые правки/пул и не заменяет опубликованный индекс. Неиспользуемые старые
generations/orphans пока не удаляются.

Реальные sidecar `.build`, C ABI `{pointer,len}`, native/JIT linkage проверены
по pinned `docs/packages.md` §3/4 и `test/packages/pkg_own_c*`. Собственный
`native/fileio.c` делает только OS I/O: fixed-buffer read/EOF, UTF-8→UTF-16 на
Windows, file lock/unlock. В нём нет формата, checksum, генератора, выбора
чанков или игровых правил. Атомарная запись использует pinned Goose stdlib;
новых third-party зависимостей и изменений toolchain pins нет.

## Проверки

**12 headless suites** прошли TinyCC/native release/debug, GCC 14.2 и 12.2.
Новый suite проверяет все 81 положения CPU-окна/отрицательные координаты,
лимит 49, CPU halo с прежним Map, грязное вытеснение и повторное чтение.
Имитации отказа страницы и публикации индекса сохраняют live state и прежний
header. Проверены truncation/CRC, неизвестный ID с исправленным CRC и неверные
координаты с исправленным CRC/index binding. Повреждённый incoming page
отвергается до изменения пула. Два lock handles одновременно не открываются.

Python независимо разбирает index/page bytes, checksums, координаты, counts,
reserved fields и связи. Native/JIT создание и export совпали с прежним
независимым SHA-256 81-чанкового мира seed 12345. Импорт/экспорт 1/9/81 чанков
вернул исходные GCW побайтно, исходники не менялись. Malformed index и bulk
import размером **1 ГБ** отвергнуты fixed-buffer reader без публикации индекса.
Прежние четыре v1 и четыре v2 SHA-вектора сохранены.

**121 Vulkan/Xvfb сценарий** в pinned Docker с network=none: прежние 111
плюс 10 paged-проверок. 112 основных PNG, 31 raw profile; есть отдельный
предварительный smoke. Все PNG SHA проверены, summary независимо пересчитаны
из samples. API misuse count = 0. Khronos validation layer не запускался.

Маршрут: обычные injected input events, X от 31,5 до **69,62551**, путь
38,12551 блока, один break/place, 9 прыжков, R назад в X=10,5.
За 680 кадров — **24 CPU eviction, один опубликованный commit/страница,
одно admission сохранённой страницы с диска**, 48 admission генератора.
CPU peak на этом маршруте с mesh-radius 1 — 25, физический пул всё равно 49.
На дальнем участке до R осталось 16 CPU-чанков с закреплённым стартовым.
При обычном mesh-radius 2 idle имеет 49 резидентных CPU-чанков.

PNG и игровое состояние совпали с полным CPU Map: вдалеке (600 кадров), после
R (680), window/offscreen/debug и после импорта. Сравнивались одинаковые GPU
области. Это equality сохранённых кадров, не всех кадров догрузки. Экспорт
четырёх paged сеансов после игры совпал с GCW контрольной игры побайтно.
Повторное открытие не изменило ни индекс, ни одну страницу. Импорт не изменил
GCW-источник. [Машиночитаемый итог](validation/paging/paging-results.json).

## Цена и ограничения

[Таблица локальных замеров](validation/paging/comparison.md),
[raw profiles](validation/paging/profiles/),
[PNG hashes/counters](validation/paging/render-results.json),
[source hashes/toolchain](validation/paging/provenance.json).

Это оптимизация блоковой резидентности, не доказанный рост FPS. В одном
последовательном idle-прогоне p50 CPU wall paged **2,0788 мс**, полный Map
**1,6271 мс**. I/O синхронное, CPU lookup косвенный, данные иногда читаются
дважды для preflight. Возможны задержки на границе/после R. Один прогон CPU
Vulkan не устанавливает устойчивую разницу скорости; GPU timestamps и общий
RSS/VRAM не измерены. Преимущество над Minecraft не заявляется.

В новом procedural мире после одного изменённого чанка опубликованные данные
занимают index 1024 + page 4128 байт (без filesystem overhead). Но диск может
расти от старых generations; импортированный мир хранит все страницы.
Bulk import/export использует полный Map и отдельные bounded buffers, его
пик памяти не равен рабочему пулу. Маленькие импортированные миры могут
занимать в CPU больше прежнего Map; переход остаётся явным.

После I/O failure игра останавливается с 8, не использует missing blocks
как воздух и пытается сохранить pending. При недоступной записи несохранённые
изменения могут потеряться, последний опубликованный checkpoint остаётся.
Один процесс на мир; стороннее изменение файлов/сетевые FS не проверялись.
Power-loss fault injection не выполнялся.

Все три jobs [GitHub Actions 41081936076](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076)
для source `5bd71bdcba539abade725fe62df23344d53cb1f5` завершились success:
Windows native/JIT, собственный C ABI/Unicode I/O/lock, CLI/launcher,
Linux и 121 графический сценарий.
[Windows ZIP 0.10](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41081936076/artifacts/12990900263)
создан; metadata/digest и границы — в [github-ci.md](github-ci.md).
GUI на Windows 10 и физический GPU пока не проверены. Linux lavapipe/Xvfb
этого не заменяет. Сети Java Edition и бесконечного мира ещё нет.

Локальная Linux-поставка собрана из уже проверенных native outputs. Из `/tmp`
выполнены headless `--version`, graphical `--help` без открытия GUI и полная
проверка paged-store упакованным headless-клиентом. Индекс/страницы не изменились;
оба бинарника совпали с тестовыми, 12 файлов лицензий сохранились побайтно.
BUILD-INFO указывает 0.10.0, source `5bd71bd`, world formats [1,2,3], profiling
schema 1. Миры и debug-программы отсутствуют.
[Проверка состава](validation/paging/package-results.json) относится к Linux,
не к скачанному Windows ZIP.
