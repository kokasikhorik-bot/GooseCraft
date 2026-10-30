# GooseCraft

Самостоятельный нативный клиент на Goose для Windows 10 x64, разрабатываемый
полностью в Codex Cloud. Цель — реализация поведения Minecraft Java Edition
с отдельным лаунчером. Текущий этап **0.3.0-stage3 — первый игровой цикл**:
движение от первого лица, прыжок, коллизии, выбор, разрушение и установка блоков.
Это небольшой собственный voxel-прототип: одного чанка, двух типов блоков
и временного мира достаточно для первых проверок управления. Сохранения,
сеть, бесконечный мир и совместимость с Java Edition ещё не реализованы.

![GooseCraft: вид от первого лица](docs/validation/stage3/play-window.png)

## Компоненты

- `goosecraft-client`: окно 640×480, камера игрока, прицел, обводка выбранного
  блока и подсказки управления. Мир, физика, выбор/изменение блоков, геометрия,
  HUD и управление рендерером написаны на Goose. GLSL преобразует вершины и цвет.
- `goosecraft-headless`: независимый консольный тестовый клиент без SDL и GPU.
- `goosecraft.cmd`: Windows-лаунчер. По умолчанию открывает графический клиент;
  с первым аргументом `--headless` запускает headless-клиент и передаёт ему аргументы.
- Python используется только для сборки, проверок и упаковки. Оригинальный
  Minecraft, Horizon и JVM не запускаются. Minecraft-ресурсов в поставке нет.

## Управление

WASD — движение; мышь или стрелки — обзор; Space — прыжок; левая кнопка мыши —
удалить выбранный блок; правая — поставить; 1/2 — зелёный/янтарный материал.
Escape освобождает мышь и ставит игру на паузу, клик или Enter продолжает.
R возвращает на старт; F10 или закрытие окна завершает игру.
Изменения мира теряются после выхода. [Первый запуск на Windows](docs/first-play.md).

## Проверки в облаке

Пользователю пока ничего не требуется устанавливать на Windows.
На существующем облачном x64-хосте с Git, Python, make и C/C++20-компилятором:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements.txt
.venv/bin/python tools/bootstrap.py --jobs 2
.venv/bin/python tools/project.py test
./build/goosecraft-headless --headless --ticks 20
```

```json
{"mode":"headless","ticks":20,"solid_blocks":256}
```

Для графики в облачном Docker:

```sh
docker build --target graphics -f .devcontainer/Dockerfile -t goosecraft-graphics .
mkdir -p graphics-results
docker run --rm --network=none \
  --mount "type=bind,src=$PWD/graphics-results,dst=/results" \
  goosecraft-graphics python tools/project.py render-test --evidence /results
```

Если облако использует дополнительный proxy CA, добавьте к `docker build`
`--secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt`.
Тест использует Mesa lavapipe и Xvfb; физическая видеокарта не требуется.
Обычный Docker build без `--target graphics` сохраняет отдельное headless-окружение.

## Windows-сборки

[Workflow](.github/workflows/build.yml) готовит Windows x64 артефакт с обоими
исполняемыми файлами, лаунчером и лицензиями. Для запуска сборки не нужны
Goose, Python, Java или локальная среда разработки. Ожидаемый вызов лаунчера:
`goosecraft.cmd` для окна, `goosecraft.cmd --headless --ticks 20` для консольной проверки.

Публичный репозиторий: [kokasikhorik-bot/GooseCraft](https://github.com/kokasikhorik-bot/GooseCraft).
[CI игрового прототипа 0.3 — #41015539670](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670)
успешно прошёл все три jobs: Windows x64, Linux headless и Linux Vulkan/Xvfb
с игровым input replay. [Скачать Windows ZIP](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12959044218),
распаковать и запустить `goosecraft.cmd` — это первый кандидат для локальной
проверки управления. [Подробности и границы проверки](docs/github-ci.md).
Windows GUI и пользовательская Windows 10 ещё не проверены.

## Документация

- [Архитектура и этапы](docs/architecture.md)
- [Аудит компилятора](docs/goose-audit.md)
- [Облачное окружение и графические проверки](docs/cloud.md)
- [Результаты этапа 1](docs/stage-1-results.md)
- [Результаты графического этапа](docs/stage-2-results.md)
- [Игровой цикл и проверки ввода](docs/stage-3-results.md)
- [GitHub и статус CI](docs/github-ci.md)
- [Лицензии](THIRD_PARTY_NOTICES.md)

Проект не является официальным продуктом Minecraft и не связан с Mojang/Microsoft.
