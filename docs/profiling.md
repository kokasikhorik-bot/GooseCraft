# Профиль клиента GooseCraft 0.7

Коллектор и экспорт написаны на Goose (`src/core/profiling.goose`), графический
цикл использует `os.clock_ns`. API проверен по закреплённым `docs/stdlib.md`
и `stdlib/std.goose`: clock монотонный, `sort(T[:])` сортирует на месте.
Метрики помогают выбирать следующие оптимизации и размер мира. Они не
доказывают преимущество над Minecraft или измеренную скорость Windows GPU.

## Запуск без инструментов разработки

```bat
goosecraft.cmd --no-save --profile run-001.json
goosecraft.cmd --no-save --profile run-002.json --profile-warmup 60
```

Профиль появляется при штатном выходе (F10/закрыть окно). Можно открыть JSON
обычным текстовым редактором. `--profile` сам по себе не включает временный
мир: без `--no-save` действуют обычные сохранения. Мир сохраняется до выгрузки
профиля. Принудительное завершение процесса теряет ещё не записанный профиль.

По умолчанию первые 30 завершённых кадров считаются прогревом; допустимый
`--profile-warmup` — 0..10000, только вместе с `--profile`. Хранятся последние
1024 кадра после прогрева. Длинный сеанс перезаписывает старые элементы кольца,
не увеличивая хранилище. Отключённый профиль не собирает samples и не вызывает
clock_ns; его массив владельцев пуст. Общая нулевая стоимость режима не заявляется.

Нужен новый путь. Существующий файл/каталог отвергается до открытия GPU
(exit 7); исходный файл сохраняется. Совпадение строк пути с `--world` или
`--screenshot` — ошибка аргументов 2. Повторная проверка перед выгрузкой
защищает, например, мир, появившийся по другому написанию того же пути.
Одновременные записи разных процессов в один путь не поддерживаются:
это проверка существования плюс `write_file_atomic`, не exclusive-create API.
Ошибка выгрузки — exit 7 и сообщение; ошибка сохранения мира остаётся exit 6.

## Что именно измеряется

`wall_ns`: от входа в `gfx::frame()` до завершения `gfx::end_pass()` текущей
итерации. Источник `goose_gfx/src/gfx/gfx_device.c` проверен: `frame()`
показывает/отправляет предыдущий кадр и обрабатывает события. Замер не является
временем GPU, интервалом между показанными изображениями или независимым FPS.
Он включает ожидания драйвера и вытеснение процесса операционной системой.

| Столбец | Границы |
| --- | --- |
| `pump_ns` | `gfx::frame()`: отправка/показ предыдущего кадра, ожидание swapchain, события, API checks |
| `game_ns` | Клавиши, фокус/пауза, физика, raycast/редактирование до remesh |
| `mesh_ns` | Dirty scan, halo, CPU mesher/stitch, резервирование/загрузка буферов; не GPU execution time |
| `save_ns` | Проверка F5 и синхронная запись мира при запросе |
| `submit_ns` | Камера, HUD/outline, culling и запись команд рисования до `end_pass`; команды могут исполняться позже |

В каждой строке сумма пяти частей точно равна `wall_ns`. Процентили частей
по отдельности не обязаны складываться в процентиль полного цикла.
Детерминированный replay по-прежнему использует 1/60 s для физики, но профиль
измеряет настоящие часы, а не это моделируемое время.

Отдельно записываются:

- `startup_ns` и вложенный `initial_mesh_ns`, включая подготовку начальных
  GPU-буферов. Прогрев не убирает эти данные: он относится к samples цикла.
- `loop_session_ns`: весь интервал цикла, включая прогрев, replay injection,
  сбор samples и управление циклом. Он может содержать последний вызов
  `frame()`, на котором пришло закрытие и полный кадр уже не рисовался.
- `collector_ns_total`: дополнительный замер после `end_pass`, включающий
  чтение счётчиков буферов и запись sample. В `wall_ns` он не входит.
- `tail_flush_ns`: финальная отправка и ожидание завершения GPU. Особенно
  важен для offscreen, где нет ограничения со стороны оконного swapchain.
- `exit_readback_ns`: чтение/проверка пикселей и screenshot/PNG I/O, только
  при `--screenshot`. Этот этап может включать два readback в текущем gfx API.
- `exit_save_ns`: проверка и запись мира при выходе.

Запись самого JSON и освобождение gfx при закрытии в эти интервалы не входят.
Во время кадра нет сортировки/записи JSON; явное F5, конечно, пишет мир.

## Схема 1

Файл содержит `schema=1`, `client_version`, `driver`, флаги режима, `clock`,
описание scope и метод `nearest-rank on retained samples`. Нет путей файлов,
учётных данных и пользовательских строк в JSON; driver — контролируемый тег
`vulkan`, `direct3d12`, `metal`, `unknown` либо `headless` для тестовых fixtures.

`seen` — все завершённые итерации; `warmup_discarded` — исключённый прогрев;
`retained` — размер текущего окна; `overwritten` — вытесненные старые samples.
Пустое окно допустимо, например 3 кадра при прогреве 30; summary тогда нулевой.

`columns` задаёт порядок чисел в массивах `rows`:

```text
frame, wall_ns, pump_ns, game_ns, mesh_ns, save_ns, submit_ns,
rebuilt, draw_calls, uploaded_bytes, paused, save_calls
```

Все значения — целые. `paused`/`save_calls` — 0 или 1. Номера кадров исходные,
последовательные, после rollover не начинаются заново. `rebuilt` не включает
начальные меши; `uploaded_bytes` включает mesh, HUD и outline этого кадра,
исключая начальную загрузку мешей. `draw_calls` включает HUD/outline.

Для шести временных полей `summary` хранит `count/min_ns/p50_ns/p95_ns/p99_ns/
max_ns/mean_ns`. Ближайший ранг: `sorted[ceil(p*N/100)-1]`, без интерполяции.
`mean_ns` — целая часть среднего. При чётном N это определение p50 может
отличаться от среднего двух центральных значений.

Sample — 12 i64, кольцо логически 98304 байта плюс поля управления/владелец.
Это не весь расход памяти профайлера: при выгрузке есть scratch 1024 i64,
JSON-массив и служебные значения. Размер samples подтверждается `bytes_of`.

Из памяти/аллокаций доступны только известные счётчики:
`world_block_capacity_bytes`, `active_world_block_bytes`, `mesh_bytes`,
`mesh_capacity_bytes`, `mesh_buffer_creations`, `overlay_buffer_capacity_bytes`,
`overlay_buffer_creations`. Это запросы к GPU API и storage блоков, не все
аллокации клиента, не RSS/VRAM процесса и не данные системного профайлера.

В 0.8 добавлены metadata `world_radius`, `world_chunks`, `world_format`.
У синтетических headless fixtures без мира это -1/0/0. `world_block_capacity_bytes`
теперь описывает логические выделенные слоты расширяемого массива (минимум
девять для старого single-chunk diagnostic), а не размер всего Map/резерва
data stack. Дополнительные metadata не меняют порядок columns/rows schema 1.

В 0.9 добавлены `mesh_radius`, `resident_chunks`, `peak_resident_chunks`,
`mesh_evictions`, `initial_meshes`, `initial_uploaded_bytes`,
`peak_mesh_capacity_bytes`. Накопленные uploads/allocations/rebuilds не
сбрасываются при вытеснении; `mesh_bytes` и `mesh_capacity_bytes` описывают
текущие живые API-буферы, peak — максимум на границах кадров/после initial build.
SDL может отложить физическое удаление до завершения GPU-команд; эти значения
не измеряют полную VRAM. Raw columns по-прежнему schema 1, 12 целых на кадр.

В 0.10 `--paged-world` даёт `world_format=3`. `world_block_capacity_bytes`
для этого backend всегда 200704 (49 слотов), active bytes — текущие CPU-чанки.
Добавлены `cpu_resident_chunks`, `cpu_peak_chunks`, `cpu_evictions`,
`page_commits`, `page_writes`, `page_loads`. Load означает admission сохранённой
страницы в пул, не число системных чтений: preflight читает входящие данные
до изменения пула. `game_ns` теперь включает CPU-подгрузку/commit при движении;
это синхронное I/O, не только физика. F5 остаётся в `save_ns`.

В 0.11 добавлены `async_paging`, `prefetch_hits`, `main_page_reads`,
`main_page_read_ns`, `prefetch_worker_ns`, `prefetch_join_ns`,
`prefetch_staging_bytes`, `main_disk_page_reads`, `worker_disk_page_reads`,
`diagnostic_page_delay_ms`, `diagnostic_worker_delay_ms`.
Page reads здесь — вызовы подготовки (из файла либо seed). Disk page reads —
попытки чтения файлов страниц; это не число kernel syscalls. Метрики main
относятся к игровому циклу, начальная загрузка до worker сюда не входит.
Worker time измеряется параллельно и не складывается с frame wall.
Join измеряется отдельно после GPU flush; искусственная worker-delay туда
может попасть, но не входит в worker preparation time. Page-delay входит
в подготовку; ненулевые diagnostics нельзя выдавать за hardware benchmark.
Raw columns/schema 1 остаются прежними.

`tools/profile_readback.py` независимо проверяет схему, порядок, разложение
времени, rollover и все процентили/среднее по сырым rows; используется в CI.

## Чтение кадра при выходе

В 0.7 обычный запуск без `--screenshot` больше не вызывает `gfx::read_pixels`
для диагностического подсчёта цвета. Stdout явно возвращает
`readback_performed=false`, `colored_pixels=-1` (не измерялось).
С `--screenshot` сохранены чтение/проверка пикселей и PNG; это используют
прежние графические проверки. Финальный flush и API checks сохранены.
Это сокращение работы при выходе, не заявленное повышение FPS во время игры.
