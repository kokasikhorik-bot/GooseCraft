# GooseCraft

Нативный клиент на Goose, разрабатываемый полностью в облаке для Windows 10 x64.
Цель — самостоятельная реализация поведения Minecraft Java Edition с отдельным
лаунчером. Текущий этап **0.1.0-stage1 — проверка инструментария и headless-основа**.
Играбельного прототипа, графики, сетевого протокола и совместимости миров ещё нет.

## Что уже есть

- Закреплённый Goose, собранный из исходников, без графических пакетов.
- Самостоятельный нативный клиент: тестовый чанк 16³, слой из 256 блоков и счётчик шагов.
- Goose-тесты блоков и симуляции; проверки TinyCC и нативной сборки, release и debug.
- Начальный Windows-лаунчер `goosecraft.cmd`: запускает соседний клиент, передаёт
  аргументы и возвращает его код завершения. Графического интерфейса пока нет.
- GitHub Actions для Linux и Windows x64 с артефактами. Workflow создан, но
  удалённый запуск из этой сессии не выполнен: GitHub-репозиторий не подключён.

Вся логика клиента — в `src/*.goose` и `src/core/*.goose`. Python обслуживает
только сборку и проверки. Java, оригинальный Minecraft и Horizon не запускаются.

## Работа в Codex Cloud

Пользователю пока ничего не нужно устанавливать на Windows. Команды ниже
выполняются разработчиком в облаке с Git, C/C++20-компилятором, Python и make:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements.txt
.venv/bin/python tools/bootstrap.py --jobs 2
.venv/bin/python tools/project.py test
.venv/bin/python tools/project.py package
./build/goosecraft-client --headless --ticks 20
```

Ожидаемый вывод клиента:

```json
{"mode":"headless","ticks":20,"solid_blocks":256}
```

Сценарии `bootstrap.py` и `project.py` работают также на Windows с `python` из
GitHub Actions. Windows-сборка использует MSVC установленного runner. После
подключения репозитория каждый push/PR запускает `.github/workflows/build.yml`.
Артефакт содержит клиент, `.cmd`-лаунчер, исходные лицензии и сведения о версии;
для запуска будущей Windows-сборки Goose, Python и Java не понадобятся.

## Документация

- [Архитектура и этапы](docs/architecture.md)
- [Проверка Goose и источники API](docs/goose-audit.md)
- [Облачное окружение](docs/cloud.md)
- [Результаты этапа 1](docs/stage-1-results.md)
- [Лицензии](THIRD_PARTY_NOTICES.md)

Проект не является официальным продуктом Minecraft и не связан с Mojang/Microsoft.
