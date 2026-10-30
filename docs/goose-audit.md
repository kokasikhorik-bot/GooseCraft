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
Goose API и не изменение pinned upstream. Эффект на целевой Windows проверяется CI.
