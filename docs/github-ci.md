# GitHub и проверка CI

2026-10-29 создан приватный репозиторий
[kokasikhorik-bot/GooseCraft](https://github.com/kokasikhorik-bot/GooseCraft).
Оба коммита этапов 1–2 загружены в `main`, локальный `origin` настроен на
`https://github.com/kokasikhorik-bot/GooseCraft.git` без учётных данных в URL.

## Реально наблюдаемый результат

Первый push запустил workflow
[Native builds and rendering, run 40947702634](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/40947702634)
для commit `1b83739d375ccb71875e515632d956485e69ae58`.
GitHub зарегистрировал три jobs, но **ни одному не выделил runner**:

| Job | Результат GitHub | Runner | Выполненные шаги |
| --- | --- | ---: | ---: |
| ubuntu-22.04 / x64 | failure | 0 | 0 |
| windows-2022 / x64 | failure | 0 | 0 |
| Linux / software Vulkan and X11 | failure | 0 | 0 |

Аннотация GitHub для Windows job и graphics job:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

Это блокировка Actions на уровне аккаунта. Компилятор и тесты в GitHub runner
не запускались; количество артефактов в API — 0. Успешная Windows-сборка,
Windows-лаунчер и Windows GUI по-прежнему не подтверждены.
Проверенные в Codex Cloud Linux-сборки и GPU-кадры остаются описаны в
[отчёте этапа 2](stage-2-results.md).

Нормализованные данные ответов GitHub REST API сохранены в
[github-actions-40947702634.json](validation/github-actions-40947702634.json).
Секреты и заголовки авторизации в отчёт не включены.

## Историческая блокировка приватного запуска

Для приватного репозитория владелец должен проверить
[GitHub Billing & plans](https://github.com/settings/billing): состояние платежей
и лимит Actions. После исправления можно выполнить Re-run jobs либо запустить
workflow вручную через workflow_dispatch.

Другой вариант — явно согласовать публичность репозитория и повторить CI.
Это опубликует исходники и историю; такая смена видимости не выполняется
без решения владельца. Она также не является гарантией снятия всех ограничений
аккаунта. Настройки оплаты автоматически не менялись.

Документационные обновления этого статуса отправляются с `[skip ci]`, чтобы
не повторять заведомо заблокированные запуски без изменения условий.

## Публикация — 2026-10-30

Владелец явно разрешил сделать GooseCraft публичным. GitHub API подтвердил
`private: false`, `visibility: public` для
[kokasikhorik-bot/GooseCraft](https://github.com/kokasikhorik-bot/GooseCraft).
Настройки оплаты не менялись. Выполняется повторная проверка CI в публичном
репозитории; первоначальный отказ приватного запуска сохранён выше как история.

Первый публичный запуск
[41009915165](https://github.com/kokasikhorik-bot/GooseCraft/actions/runs/41009915165)
получил runners. Windows остановился на setup-python: 3.12.14 не найден для
Windows 2022. В matrix закреплён доступный Windows Python 3.12.10; Linux
остаётся на 3.12.14. Причина подтверждена аннотацией Actions и официальным
[manifest](https://raw.githubusercontent.com/actions/python-versions/main/versions-manifest.json).
