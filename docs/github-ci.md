# GitHub: успешный CI GooseCraft 0.4 — 2026-10-30

## Оптимизация 0.4

[Run 41022704811](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811)
для `e4c49678cc65f014425ba2fc8923ce08dacea703` завершился **success**.
Все три jobs прошли на GitHub-hosted runners:

| Job | Результат | Проверки |
| --- | --- | --- |
| windows-2022 / x64 | success | Release/debug графического клиента, TinyCC/native core/mesh/player в release/debug, CLI, реальный cmd.exe-лаунчер, native benchmark и упаковка |
| ubuntu-22.04 / x64 | success | Headless core/mesh/player, CLI, native benchmark и упаковка |
| Linux / software Vulkan and X11 | success | Закреплённый Docker, 14 графических сценариев без сети, проверка поверхности/изображения, кеширования и GPU capacity |

**[Windows ZIP 0.4](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962646663)**:
`goosecraft-windows-2022-x64-e4c49678cc65f014425ba2fc8923ce08dacea703`,
1 468 368 байт. Содержит release `goosecraft-client.exe`, headless-клиент,
`goosecraft.cmd`, документацию и лицензии. Debug EXE и benchmark EXE в поставку
не включаются. [Первый запуск](first-play.md).

GitHub API сообщил digest ZIP:
`sha256:69d3136d17978e63a15a7602fba6b69f97d808d488c5e472de6b3cf4fd1157df`.
По API срок хранения — до `2027-01-28T07:51:59Z`, если артефакт не удалят раньше.
ZIP в этой сессии не скачивался; digest не пересчитан локально. Ранее proxy
блокировал redirect на Actions storage, это ограничение описано в истории.
Наличие и размер подтверждены API; `.exe` выполнялись непосредственно в Windows job.
Для скачивания Actions artifact может потребоваться вход в GitHub.

Отдельные artifacts:

- [Windows benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962860898): 2 505 байт.
- [Linux benchmark](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962153282): 2 540 байт.
- [Graphics evidence PNG/JSON](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962721280): 58 613 байт.
- [Linux headless](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41022704811/artifacts/12962651528): 268 517 байт.

Полные [run/jobs/steps/artifacts](validation/github-actions-41022704811.json)
сохранены без заголовков авторизации и credentials. Windows benchmark выполнился,
но его численные результаты здесь не цитируются: artifact внутрь облака не
скачивался. Таблица CPU-времени в [optimization-1.md](optimization-1.md) относится
к отдельным локальным облачным Linux GCC 14.2/12.2 замерам.

Границы: Windows job запускал графический EXE для `--help` и ошибочных аргументов;
окно на Windows и пользовательская Windows 10 не проверены. Linux replay
использует SDL/gfx-инъекцию ввода, не физические устройства. Между optimized
window/offscreen/debug проверяется точное совпадение PNG и состояния. Между
greedy/reference поверхность точна, но растеризация полного replay имеет два
граничных пикселя разницы; тест допускает максимум четыре, строго вне HUD,
только на общей границе фон/геометрия. Это не заявление о побайтно одинаковой
картинке со старым мешером или более высоком полном FPS, чем Minecraft.

Итоговая документация отправляется отдельным docs-only commit с `[skip ci]`;
исходники и workflow после успешного run не меняются. Документы в ZIP отражают
состояние на момент сборки, актуальный итог CI находится в этом отчёте.

## История: успешный игровой прототип 0.3 — 2026-10-30

## Игровой цикл 0.3

[Run 41015539670](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670)
для commit `27f31391bf5c9951d2d10d5d2c275869f557c999` завершился **success**.
Это исходники первого игрового цикла: WASD/мышь, прыжок, коллизии, выбор,
удаление/установка блока, перестроение меша, HUD и пауза.

| Job | Результат | Проверенное поведение |
| --- | --- | --- |
| windows-2022 / x64 | success | Компилятор Goose, release/debug графического клиента, TinyCC/native core/mesh/player в release/debug, CLI, настоящий cmd.exe-лаунчер и упаковка |
| ubuntu-22.04 / x64 | success | Компилятор, headless core/mesh/player в четырёх режимах, CLI и упаковка |
| Linux / software Vulkan and X11 | success | Graphics Docker из закреплённых исходников, десять render/input сценариев без сети, включая игру в Xvfb и совпадение release/debug/window/offscreen |

**Новый [Windows ZIP 0.3](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12959044218)**:
`goosecraft-windows-2022-x64-27f31391bf5c9951d2d10d5d2c275869f557c999`,
1 372 675 байт. Включает release `goosecraft-client.exe`, `goosecraft-headless.exe`,
`goosecraft.cmd`, документацию и лицензии. Debug EXE не включён в поставку.
GitHub API сообщил SHA-256 ZIP:
`eb0544d4f04f3ae7cbc1ab20ab4984d00a1b38e8314b351eba9585a0619786ee`.
Для скачивания Actions artifact через браузер может потребоваться вход в GitHub.
[Инструкция первого запуска](first-play.md).

Также созданы [Linux headless ZIP](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12958964279)
(176 360 байт) и [PNG/JSON/Vulkan evidence](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41015539670/artifacts/12959672378)
(40 588 байт). [Полные метаданные API](validation/github-actions-41015539670.json)
содержат tested SHA, jobs/steps и artifacts; credentials не включены.

Границы проверки: Windows job открыл графический EXE только для `--help`
и ошибочных аргументов, окно не запускалось. Реальный графический запуск
подтверждён на Linux software Vulkan/X11 в Xvfb. Replay использует инъекцию
событий SDL/gfx и фиксированное время; физические устройства ввода он не
проверяет. Пользовательская Windows 10, её Direct3D/GPU driver и GUI ещё
не проверены. Это первый кандидат для такого локального теста.

Новый ZIP в Codex Cloud не скачивался: размер и digest здесь получены от API,
а не пересчитаны по локальному архиву. Предыдущее скачивание Actions ZIP
было заблокировано proxy на redirect storage (описано ниже). Проверки `.exe`
выполнены непосредственно в Windows job.

Отчёт после успешного run сохраняется отдельным docs-only commit с `[skip ci]`.
Проверенные исходники и workflow при этом не меняются. Сопроводительные документы
в ZIP соответствуют состоянию на момент сборки; итог CI публикуется здесь.

## История: графическая основа 0.2 — 2026-10-30

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
