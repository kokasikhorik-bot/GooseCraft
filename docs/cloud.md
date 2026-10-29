# Облачная сборка

Пользовательская Windows 10 x64 не участвует в сборках первого этапа.
Работа ведётся в Codex Cloud; Windows-артефакты собирает GitHub Actions.

## Закрепление входов

- Goose: полный commit и отключённые builtin packages в `toolchain.lock.json`.
- CMake: 3.31.6, SHA-256 Linux/Windows wheels в `tools/requirements.txt`.
- Python в CI: 3.12.14 x64; GitHub Actions закреплены по commit SHA.
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

Выполнение workflow требует GitHub-репозитория. В текущем workspace Git remote
не настроен, credentials для GitHub не привязаны; push и Actions не выполнялись.
Наличие YAML не означает, что Windows-сборка уже прошла. Windows Server runner
также не заменяет будущую проверку игры на Windows 10 с настоящим видеодрайвером.
