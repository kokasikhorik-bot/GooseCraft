# Этап 1: результаты проверки, 2026-10-29

## Выполнено на облачном Linux x64

Собран Goose `cce94b919d27458856ae2685974049eac78debcf`, runtime
`f2981814a754`, CMake 3.31.6, GCC 14.2.0, Python 3.12.14, Debian 13.
Встроенные графические/физические пакеты отключены. Источники и API описаны
в [аудите](goose-audit.md), окружение — в [cloud.md](cloud.md).

| Проверка | Результат |
| --- | --- |
| `bootstrap.py --jobs 2` и повторный запуск | Успех; точный commit, Release-компилятор |
| `goose check` клиента и ядра | Успех |
| Неверное присваивание строки в i64 | Отклонено настоящим компилятором, exit 1 |
| Goose format check | Успех для исходников и headless-тестов |
| Goose-тесты через TinyCC | Успех в release и `--debug` |
| Те же тесты через native executable | Успех в release и `--debug` |
| Все 4096 координат чанка | Запись/чтение и количество блоков проверены |
| Отрицательные координаты и координата 16 по каждой оси | Запись отклоняется без изменения чанка |
| Удаление блока, исходно пустой чанк, плоская фикстура | Успех; 4095 / 0 / 256 твёрдых блоков соответственно |
| 100 последовательных шагов ядра | Состояние содержит 100 шагов |
| Native против TinyCC: 0, 1, 20, 1000, 1000000 шагов | Совпадение JSON и stdout |
| CLI: default, help, version | Успех |
| Девять ошибочных CLI-вызовов | Exit 2 и диагностика, включая переполнение входного числа |
| Запуск из другого рабочего каталога с пробелами | Успех |
| `project.py package` | Успех; нативный клиент и лицензии в `dist/goosecraft-linux-x64/` |
| Запуск упакованного клиента без GOOSE_HOME / GOOSE_STDLIB | Успех |
| Проверка формата бинарника | ELF 64-bit x86-64; `ldd` показывает libc, загрузчик и vDSO |
| SHA-256 закреплённого Linux CMake wheel | Проверен `pip download --require-hashes` |

Текущий результат запуска:

```text
$ ./build/goosecraft-client --headless --ticks 20
{"mode":"headless","ticks":20,"solid_blocks":256}
```

Логи не являются синтетическими примерами:

- [bootstrap-linux-host.log](validation/bootstrap-linux-host.log)
- [linux-host.log](validation/linux-host.log): 36 реальных запусков инструментов и программ,
  включая ожидаемую ошибку типов и ошибки CLI.
- [environment.json](validation/environment.json): версии и формат бинарника.

## Изолированное воспроизведение

Финальный `.devcontainer/Dockerfile` реально собран с пустым кешем Goose и
закреплённым amd64 base image. Внутри: Debian bookworm, GCC 12.2.0, Git 2.39.5,
Python 3.12.14 и CMake 3.31.6. Получен тот же Goose commit и runtime hash.
Затем выполнен `docker run --rm --network=none goosecraft-stage1`: **exit 0**,
все compiler/core/CLI проверки прошли без дисплея и доступа к сети.
Это проверка воспроизводимой процедуры в другом окружении, не утверждение
о побитовом совпадении GCC 12 и GCC 14 бинарников.

- [docker-build.log](validation/docker-build.log): настоящая сборка образа и Goose.
- [linux-container.log](validation/linux-container.log): настоящий запуск тестов.
- [venv-setup.log](validation/venv-setup.log): отдельное чистое Python venv,
  установка CMake с проверкой SHA-256 из заранее скачанного wheel и повторный bootstrap.

## Что ещё не подтверждено

- На момент этапа 1 GitHub Actions не запускался: remote не был задан.
  Позднейшая публикация и результат первого CI описаны в [github-ci.md](github-ci.md).
  Workflow подготовлен; настоящую Windows x64 сборку и `.cmd`-лаунчер проверит
  Windows job после разблокировки Actions. Их успех сейчас не заявляется.
- Нет запуска GUI, GPU-кадра или Windows 10. Headless-успех этого не доказывает.
- Нет играбельности, Minecraft-протокола, совместимости файлов/генерации мира
  или доказательства эквивалентности Java Edition.
- Полный upstream test suite Goose не запускался. Проверены перечисленные
  сценарии проекта; предупреждения исходников Goose не исправлялись.

Исходники клиента написаны на Goose. Лаунчер — отдельный начальный cmd-скрипт,
Python — инструментарий. Никакой запуск оригинального Minecraft или Horizon,
скачивание игровых ресурсов или JVM для этих проверок не использовались.
