# Аудит Goose — 2026-10-29

## Закреплённые источники

- [Goose README](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/README.md),
  commit `cce94b919d27458856ae2685974049eac78debcf` (HEAD на момент проверки).
- [Tutorial](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/docs/tutorial.md),
  [Reference](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/docs/reference.md),
  [CLI](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/docs/command_line.md),
  [Packages](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/docs/packages.md),
  `CMakeLists.txt`, `stdlib/os.goose`, `stdlib/std.goose`, `src/blessed.txt`.
- Для графики изучен настоящий
  [samples/27_gfx_cube.goose](https://github.com/aardappel/goose/blob/cce94b919d27458856ae2685974049eac78debcf/samples/27_gfx_cube.goose)
  и разделы stdlib. Upstream-пример не запускался; на этапе 2 проверен собственный рендерер (stage-2-results.md).
- [Horizon README](https://github.com/horizon-rust/horizon/blob/7ebf7d26cbe58d65ef873767c639f144dc403554/README.md)
  и `launcher/README.md`, commit `7ebf7d26cbe58d65ef873767c639f144dc403554`.
  Только архитектурный ориентир: отдельный launcher, клиент, headless-ядро,
  отдельное хранение пользовательских ресурсов и проверяемые сценарии поведения.
  Заявленные авторами проценты совместимости здесь не воспроизводились.

GitHub API `/repos/aardappel/goose/releases/latest` на момент исследования
показывал `v2026.3` с архивами Linux x64, Windows x64 и macOS. В проекте выбрана
сборка конкретного исходного commit, а не автоматически меняющийся `latest`.
Установку release-архивов в этой сессии не проверяли.

## Возможности и границы подтверждения

| Возможность | По документации/исходникам | Проверка в GooseCraft |
| --- | --- | --- |
| Сборка компилятора | CMake ≥3.27, C++20, Python для runners; TinyCC в исходном дереве | Да: Release, GCC 14.2.0 на хосте и 12.2.0 в контейнере, CMake 3.31.6, Linux x64 |
| Самостоятельный native executable | `goose build`, C backend, gcc/clang/MSVC | Да: ELF x86-64 запущен отдельно от компилятора |
| In-process исполнение | `goose run` через встроенный TinyCC | Да: тесты и CLI, результат совпадает с native |
| Проверка типов и импортов | `goose check`, imports от корня пакета/относительно файла | Да: собственные модули и отклонение неверного типа |
| Отладочные runtime-проверки | `--debug`: overflow, range, tag checks | Да: ядро выполнялось в debug; исчерпывающая проверка всех ловушек не проводилась |
| Форматирование | `goose format --check` | Да: исходники клиента и headless-тесты |
| Файлы, время, argv | `stdlib/os.goose` | argv и stderr проверены; остальные API пока не тестировались |
| C ABI | `extern fn`, `export fn`, sidecar `.build` | Изучено, собственный FFI не понадобился и не тестировался |
| Потоки | `thread_fn`, отдельные data stacks, typed queues; нужен native build | Изучено, не тестировалось |
| Графика | goose_gfx, SDL3 GPU, шейдеры через `embed_shader`; Windows D3D12, Vulkan, macOS Metal | Этап 2: нативный собственный рендерер проверен на software Vulkan, offscreen и X11 в Xvfb |
| UI/звук/физика | Отдельные goose_gfx/goose_physics packages | UI/audio archives строятся в составе gfx, API не используется; physics не подключён |
| Windows x64 | Есть upstream CI, MSVC и готовые compiler releases | Наш CI этапа 2 собрал и запустил native CLI и лаунчер; актуальные результаты в github-ci.md |

## Модель памяти и архитектурные следствия

Goose — не Go. Это whole-program компилятор в C, без обычной кучи, GC,
деструкторов, escaping closures и произвольных function pointers. Динамические
данные живут inline в data stacks; время жизни проверяется компилятором.
По умолчанию каждый стек резервирует 2 GiB виртуального пространства с
постепенным commit памяти; это не 2 GiB физической памяти на массив.

Фиксированные массивы индексируются, массивы переменного размера элементов
последовательные. Resizable-данные имеют ограничения на владельцев, рекурсивные
вызовы и поля структур. Нельзя проектировать мир как неограниченный граф
самостоятельно выделяемых объектов, будто у языка обычная куча.

Для GooseCraft начинаем с фиксированного чанка, детерминированных функций и
явных владельцев. Рендерер и загрузчики будут подключаться после проверки их
реальных API, не через придуманные функции вроде `Window.create()`.

## Замечания, обнаруженные реальной сборкой

1. Исполняемый файл Goose построен вне исходного дерева, в `.cache/toolchain/build`.
   Автопоиск stdlib там не находит `.cache/upstream/goose/stdlib`. Поэтому
   `tools/project.py` явно задаёт `GOOSE_STDLIB`, а также изолирует `GOOSE_HOME`.
2. `block` — зарезервированное слово Goose. Параметр с этим именем был отклонён
   парсером; в итоговом коде используется `value`.
3. GCC 14.2 выдавал upstream warnings, в том числе `unused`, `noreturn` и
   `maybe-uninitialized`. Компилятор собрался, тесты прошли; это не утверждение,
   что предупреждения исправлены или полный upstream suite выполнен.
4. Goose сейчас Apache-2.0, Horizon — MIT. Полные тексты сохранены отдельно.

## Дополнение этапа 2

Реальные `gfx::open`, `open_headless`, `vertex_buffer`, `index_buffer`,
`pipeline`, `begin_screen`, `draw_indexed`, `uniforms`, `frame`, `flush`,
`read_pixels`, `screenshot` и `driver` взяты из pinned gfx.goose, а не придуманы.
Собственные шейдеры прошли compile-time `embed_shader`; выполнен Vulkan-рендеринг.
Проверка платформ и ограничения описаны в [stage-2-results.md](stage-2-results.md).
GUI на Windows из успешного Linux-теста не выводится.

## Дополнение этапа 0.5

Реальные `os.read_file`, `write_file_atomic`, `make_dir`, `env`, `resource_dir`
проверены по pinned `stdlib/os.goose` и реализации `runtime_os.h`, файловое I/O
выполнено TinyCC/native в release/debug на Linux. Windows CI проверяется
отдельно. Неподдерживаемый bounded-stream API не придумывался: текущий
`read_file` читает целый файл, ограничение явно описано в world-format.md.

Для деления координат использован реальный `std.div_euclid`: у Goose `/`
отбрасывает дробь, а `%` всегда неотрицателен. Ошибка C-подобного предположения
поймана тестом -17/-16/-1 до публикации кода. Generic-функции player/mesh/
interaction инстанцируются для Chunk/Map/Halo там, где это нужно; мировая
логика не перенесена в другой язык. `gfx.row`, `translate`, `mul` взяты из
действительного math API gfx; CPU frustum-тесты не зависят от него.

Обнаружена разница JIT/AOT на Windows: `gs_os_arg` переводит narrow main argv
из CP_ACP через UTF-16 в UTF-8. Без process UTF-8 manifest символы вне ANSI
страницы теряются до этого преобразования. Сам Goose compiler содержит
`src/goose.manifest` (CMakeLists.txt:85), а команда native build его не добавляет.
Наш helper встраивает собственный manifest SDK mt.exe в каждый Windows EXE,
затем извлекает и проверяет ресурс. Это настройка приложения, не придуманный
Goose API и не изменение pinned upstream. [Наш CI 0.5](github-ci.md) подтвердил
на Windows Server 2022 native/JIT Unicode I/O после встраивания manifest.
Это не проверка GUI на пользовательской Windows 10.

## Дополнение 0.8 — проверено 2026-10-30

В pinned reference §8 «A resizable tail» разрешён изменяемый массив последним
полем структуры. Такой владелец может быть локальной переменной, параметром
или результатом, но не элементом массива и не промежуточным полем структуры.
`Map` использует фиксированные metadata/dirty-флаги и последний `Chunk[>..]`.
Пул растёт до 9/25/49/81 слота; отдельный GPU-массив содержит только фиксированные
`Cache`. Новых API или изменений upstream для этого не потребовалось.

Reference §4 «Copies are visible» и «Built in place» различает alias нефиксированного
lvalue, явный `copy()` и построение результата в месте назначения. Loader
вызывает `copy(candidate)` при замене живого мира; тесты отдельно проверяют,
что изменение копии не затрагивает оригинал. Backend при попытке `==` для
growable структуры выдал `codegen: comparing resizable structs is unsupported`.
Используется собственное сравнение metadata/блоков, без предположения о поддержке
оператора. Итоговые владельцы, копии и кодек прошли TinyCC/native release/debug
на GCC 12.2 и 14.2; Windows проверяется отдельным CI. [Результаты 0.8](large-world-results.md).

## Дополнение 0.9 — жизненный цикл GPU-буферов

Перед вытеснением мешей проверены pinned `gfx.goose:493`, реализация
`gs_gfx_release_buffer` в `src/gfx/gfx_resources.c:214` и контракт
`SDL_ReleaseGPUBuffer` в `SDL_gpu.h`. SDL откладывает физическое удаление до
безопасного момента; старый handle нельзя использовать снова. GooseCraft
сразу обнуляет handle/capacity/geometry и строит новый буфер при admission.
Накопленные счётчики не сбрасываются, чтобы профиль не получил отрицательные
upload deltas. 111 графических сценариев включают eviction/возврат, misuse=0;
это не проверка полной VRAM и не запуск Windows GUI. [Результаты 0.9](residency-results.md).

## Дополнение 0.10 — ограниченный файловый I/O

В pinned `stdlib/os.goose` `read_file` добавляет целый файл в growable builder;
API bounded read/file size не объявлен. Использован документированный sidecar
`c_sources` и ABI slice `{data,len}` из `docs/packages.md` §3/4 и реального
`test/packages/pkg_own_c_impl.c`. Собственные `.build` для client/viewer/core
строят `native/fileio.c`: чтение в переданный фиксированный slice с проверкой
EOF и OS file lock. Native/JIT проверены на Linux с UTF-8 путями; Windows
проверяется своим CI. Native executable не требует C-компилятора при запуске.

C не разбирает форматы и не содержит paging/gameplay: всё это Goose в pages/
paged_world. Использованы `_wfopen`/CreateFileW без sharing и POSIX fopen/flock,
с UTF-8→UTF-16 на Windows. В runtime_os.h отдельно проверен контракт
`write_file_atomic`: flush временного файла и замена имени; sync directory
на POSIX best effort. Не заявляется тест реальной потери питания.
Фиксированный Paged поддерживает обычное сравнение в снимках тестов,
в отличие от growable Map. [Результаты 0.10](paging-results.md).

## Дополнение 0.11 — native worker и typed queues

Проверен pinned reference §22, `test/threads/queue_bounds.goose`,
`qpoll_zero_padded.goose` и `src/runtime/runtime_threads.h`. Реальные
`thread_spawn`, `thread_wait`, `qget`, `qpoll`, `qput`, `qlimit` использованы
без собственного C-планировщика. Job, Result и аргумент Path — flat values;
мир и gfx в worker не передаются. Глобальный diagnostic delay — scalar,
который Goose копирует при spawn; изменяемой общей памяти не используется.

Native-тест обнаружил важную деталь: первый worker ID равен **0**, поэтому
признак отсутствия — -1. Очередь полная возвращает false из qput; нельзя
игнорировать этот результат. Обе очереди limit 1, outstanding job один.
Shutdown сначала принимает ожидающий Result, затем отправляет stop и wait:
producer не застревает на заполненной очереди. Проверены restart/ранний stop.

Компилятор подтвердил границу: TinyCC JIT отклоняет потоковый suite с
`JIT mode does not support threads ... TinyCC cannot place thread-local storage`.
Он проверяется native release/debug на GCC 12.2/14.2 и в Windows CI; прежние
12 suites остаются JIT/native. В worker не вызывается gfx; main-thread-only
контракт графического пакета сохранён. [Результаты 0.11](prefetch-results.md).

В 0.12 повторно проверены §22 (`qpoll` и `qput` не ждут; typed messages flat)
и `stdlib/os.goose: sleep_ms` для ограниченного pacing. Новых thread/API и
зависимостей нет; `transfer.goose` использует тот же worker. Добавленный native-only
suite проверяет stale speculative result, preflight/commit/re-read failure,
partial cancellation и повторный переход. Расширение metadata встретило лимит
`str` в 99 аргументов; JSON собирается несколькими append, API не подменялся.

В 0.13 проверены mouse_pos/mouse_relative/set_mouse_relative, cursor_visible,
key_pressed и inject_mouse в pinned gfx.goose и src/gfx/gfx_device.c. Координаты
mouse_pos — pixels screen, как и HUD. Смена relative mode сбрасывает delta;
focus loss освобождает захват и held input. Scene повторно захватывает мышь при
закрытии E/Escape и resume. В графическом replay проверены три release/recapture,
запрет look/move/jump/world edits в модальном окне и оба клика при закрытии.
Новых extern/native API и зависимостей нет. Inventory suite работает JIT/AOT.

В 0.14 используются прежние growable-tail, copy/resize и C ABI read_bounded.
MAX v4 payload потребовал увеличения общего C bound 1→2 MiB; сигнатура не
менялась, codec/height/генератор остались на Goose. Для большого read buffer
используется bounded heap tail, не фиксированный 1.3 MiB stack array.
`chunk_coord`/Euclidean `%` проверены на отрицательных Y; local Chunk/Halo
размеры 16/18 сохранены. Tall suite JIT/AOT проверяет explicit-copy roundtrip
growable-tail world и неизменность live data при malformed decode.
