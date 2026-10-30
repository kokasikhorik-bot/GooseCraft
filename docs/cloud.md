# Облачная сборка

Пользовательская Windows 10 x64 не участвует в сборках первого этапа.
Работа ведётся в Codex Cloud; Windows-артефакты собирает GitHub Actions.

## Закрепление входов

- Goose: полный commit и отключённые builtin packages в `toolchain.lock.json`.
- CMake: 3.31.6, SHA-256 Linux/Windows wheels в `tools/requirements.txt`.
- Python в CI: Linux 3.12.14 x64, Windows 3.12.10 x64; GitHub Actions закреплены по commit SHA.
- CI runners: `ubuntu-22.04` и `windows-2022`; их обновления управляются GitHub.
- Linux-контейнер: `.devcontainer/Dockerfile`, amd64-образ Python 3.12.14 /
  Debian bookworm закреплён manifest digest
  `sha256:c90be507635af19768837aa7eeb2f4ce89a74d62962a335497b9df8edfb7f19d`.
  Образ уже содержит Git, C/C++ и make, дополнительных apt-установок нет.

Это воспроизводимая процедура с закреплёнными исходниками и Linux-базой.
Побитовое совпадение бинарников между облачным хостом, контейнером и MSVC не
обещается. Версии системных компиляторов runner выводятся в лог bootstrap.

## Команды на существующем облачном хосте

Нужны x64 Linux, Python с venv/pip, Git, make и C++20/C-компилятор. Проверено
на Debian 13, GCC 14.2.0. Все производные файлы находятся в игнорируемых каталогах.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements.txt
.venv/bin/python tools/bootstrap.py --jobs 2
.venv/bin/python tools/project.py test
.venv/bin/python tools/project.py package
```

Bootstrap отказывается перезаписывать изменённые исходники Goose и проверяет
фактический commit. Его повторный запуск использует исходники и CMake build cache.
Без кеша скачивается только закреплённый commit, а не движущаяся ветка.
Сборка проекта после bootstrap выполняется с `--offline`, без пакетов из сети.

## Изолированный Linux-контейнер в облаке

```sh
docker build -f .devcontainer/Dockerfile -t goosecraft-stage1 .
docker run --rm goosecraft-stage1
```

В Codex Cloud HTTPS должен сохранять session proxy и доверенные CA. Для такой
среды проверенная форма сборки использует CA bundle через BuildKit secret:

```sh
docker build --secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt \
  -f .devcontainer/Dockerfile -t goosecraft-stage1 .
```

Секрет опционален для обычного публичного CI без такого прокси. CA не копируется
в слои образа; TLS verification не отключается. Сам запуск тестов сети не требует; реально проверен с `--network=none` (exit 0).
`.dockerignore` исключает `.git`, кеши, сборки и виртуальное окружение.
Devcontainer-конфигурация также приложена; открытие через UI devcontainers
само по себе в этой сессии не проверялось.

## Windows GitHub Actions

Workflow строит Goose из того же commit, затем нативный клиент через MSVC,
запускает headless-тесты и проверяет настоящий `cmd.exe`-лаунчер:
отсутствующий клиент → код 3; успешная передача аргументов; ошибка клиента → код 2;
пути с пробелами и чужой рабочий каталог. Затем загружает артефакт с лицензиями.
Компилятор Goose, Python и TinyCC в пользовательскую поставку не входят.

GitHub-репозиторий создан, `origin` настроен и исходники загружены в `main`.
По решению владельца 2026-10-30 он сделан публичным для повторной проверки CI.
Первый приватный запуск не получил runners из-за платежей/лимита аккаунта.
После публикации CI #41010605234 успешно выполнил Windows x64, Linux headless
и software Vulkan/Xvfb. Метаданные и ссылки на артефакты — в [github-ci.md](github-ci.md).
Наличие YAML не означает, что Windows-сборка уже прошла. Windows Server runner
также не заменяет будущую проверку игры на Windows 10 с настоящим видеодрайвером.

## Графический профиль (этап 2)

По умолчанию Docker по-прежнему создаёт `headless` target. У него нет gfx,
SDL и Vulkan, даже при наличии исходников viewer в рабочем дереве.
`--target graphics` добавляет:

- gfx `6cfa3dec2ef2a6cb19ee71548b38151094e947bd`;
- SDL `fa2c02bb6e21974a89ea9824bc53c9932abe5f9c`;
- Nuklear `9f7750296f176e506c2b24ff55bc24495e2db750`;
- X11 development headers, Xvfb, Vulkan loader и Mesa из Debian snapshot
  `20261020T000000Z`, suite bookworm. Подписи пакетов и TLS проверяются;
  отключается только проверка срока давности исторического Release.

`bootstrap.py --graphics` получает исходники, сверяет commit/submodule pins и
сохраняет upstream неизменённым. `render-build` повторно проверяет эти pins,
собирает пакет как локальную зависимость через Goose CMake wrapper с `--offline`,
компилирует `src/viewer.goose` и проверяет CLI без открытия окна.
`CMAKE_BUILD_PARALLEL_LEVEL=2` ограничивает сборку native package.

```sh
docker build --target graphics \
  --secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt \
  -f .devcontainer/Dockerfile -t goosecraft-graphics .
mkdir -p graphics-results
docker run --rm --network=none \
  --mount "type=bind,src=$PWD/graphics-results,dst=/results" \
  goosecraft-graphics python tools/project.py render-test --evidence /results
```

На облачном хосте с установленными графическими зависимостями доступны
`python tools/bootstrap.py --graphics`, `python tools/project.py render-build`
и `python tools/project.py package --graphics`. На пользовательской Windows
эти команды выполнять не требуется: это обязанность CI.

Клиент с графикой называется `goosecraft-client`, независимый консольный —
`goosecraft-headless`. Пакет `--graphics` включает оба. `.cmd`-лаунчер выбирает
headless-бинарник, если первый аргумент `--headless`; иначе графический.
Коды: неверные аргументы — 2; нет дисплея/доступного GPU — 3; ошибка PNG — 4.

Windows job теперь получает gfx, собирает графический бинарник и запускает
его `--help`/некорректные аргументы без GUI. Отдельный Linux job запускает
render-test в graphics-контейнере и публикует PNG/JSON как Actions artifacts.
Финальный публичный CI успешно выполнил все jobs, включая Windows console/launcher
и Linux graphics smoke. Windows GUI не открывался; точные границы проверки
описаны в [github-ci.md](github-ci.md).

### Доступность Python на Windows runner

Реальный повторный CI 2026-10-30 показал, что setup-python не предоставляет
3.12.14 для Windows 2022. Проверен официальный versions-manifest.json проекта
actions/python-versions: 3.12.14 опубликован для Linux, 3.12.10 есть для win32 x64.
Поэтому CI закрепляет Python отдельно по платформам. Linux/Docker остаётся на
3.12.14; версии Goose, CMake, SDL и Nuklear не менялись. Python нужен только
сценариям сборки и не включается в клиентскую поставку.
