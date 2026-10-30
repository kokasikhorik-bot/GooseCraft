# GooseCraft

Самостоятельный нативный клиент на Goose для Windows 10 x64, разрабатываемый
полностью в Codex Cloud. Цель — реализация поведения Minecraft Java Edition
с отдельным лаунчером. Текущий этап **0.2.0-stage2 — графическая основа**:
тестовый voxel-мир, мешер и рендерер. Играбельного прототипа, движения игрока,
коллизий, сетевого протокола и совместимости миров ещё нет.

## Компоненты

- `goosecraft-client`: графическая сцена 640×480, собственные цвета и два столбика
  на плоском чанке. Escape закрывает окно. GLSL-шейдеры преобразуют вершины и цвет;
  мир, построение геометрии и управление рендерером написаны на Goose.
- `goosecraft-headless`: независимый консольный тестовый клиент без SDL и GPU.
- `goosecraft.cmd`: Windows-лаунчер. По умолчанию открывает графический клиент;
  с первым аргументом `--headless` запускает headless-клиент и передаёт ему аргументы.
- Python используется только для сборки, проверок и упаковки. Оригинальный
  Minecraft, Horizon и JVM не запускаются. Minecraft-ресурсов в поставке нет.

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
Код загружен в `main`. [CI #41010605234](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234)
успешно собрал Windows x64 и Linux, проверил headless-клиент, мешер, Windows-лаунчер
и Linux Vulkan/Xvfb. [Windows-артефакт](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41010605234/artifacts/12957815526)
готов; [границы проверки и история CI](docs/github-ci.md).
Windows GUI и пользовательская Windows 10 ещё не проверены.

## Документация

- [Архитектура и этапы](docs/architecture.md)
- [Аудит компилятора](docs/goose-audit.md)
- [Облачное окружение и графические проверки](docs/cloud.md)
- [Результаты этапа 1](docs/stage-1-results.md)
- [Результаты графического этапа](docs/stage-2-results.md)
- [GitHub и статус CI](docs/github-ci.md)
- [Лицензии](THIRD_PARTY_NOTICES.md)

Проект не является официальным продуктом Minecraft и не связан с Mojang/Microsoft.
