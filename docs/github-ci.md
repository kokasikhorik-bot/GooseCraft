# GitHub: публичный репозиторий и успешный CI — 2026-10-30

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
