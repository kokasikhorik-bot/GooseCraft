# Один локальный прогон: file-backed страницы

GooseCraft 0.11.0, Linux GCC 12.2, CPU Vulkan/lavapipe/Xvfb, network=none.
Тот же мир, mesh-radius 1, один fixed-step маршрут 680 кадров, warmup 0.
Таблица разделяет обычный offscreen и окно с искусственной задержкой 2 мс.

| Метрика | Offscreen worker | Offscreen sync | Window worker +2 ms | Window sync +2 ms |
| --- | ---: | ---: | ---: | ---: |
| Main page preparations | 38 | 48 | 38 | 48 |
| Main file page reads | 38 | 48 | 38 | 48 |
| Worker file page reads | 5 | 0 | 5 | 0 |
| Consumed prepared chunks | 5 | 0 | 5 | 0 |
| Staging bytes | 32968 | 0 | 32968 | 0 |
| Main preparations total, ms | 0.6772 | 0.8387 | 79.5768 | 100.3867 |
| Worker preparations total, ms | 0.1329 | 0.0000 | 10.9329 | 0.0000 |
| Exit join, ms | 0.1700 | 0.0000 | 0.1197 | 0.0000 |
| CPU wall p50, ms | 0.0488 | 0.0489 | 1.6254 | 1.4972 |
| CPU wall p95, ms | 0.1898 | 0.1866 | 2.2392 | 1.7124 |
| CPU wall p99, ms | 0.4322 | 0.3765 | 3.1501 | 2.6651 |
| CPU wall max, ms | 1.6388 | 1.3970 | 81.4051 | 81.4184 |

Main file calls сокращены с 48 до 38, worker выполнил 5; всего 43 вместо 48.
Кеш заменяет два чтения preflight/admission одной фоновой проверкой. Это
числа данного маршрута: при неверном прогнозе возможна лишняя работа.
Page read attempts — обращения к helper для страницы, не kernel syscalls.
CPU wall содержит ожидание GPU/driver, не GPU timestamps/FPS. Два режима
исполнялись последовательно, по одному разу; устойчивый FPS-коэффициент не установлен.
Крупнейший кадр ~81 мс в обоих +2 ms сценариях: R использует fallback.

[Raw profiles](profiles/), [результаты/PNG hashes](render-results.json), [инварианты](prefetch-results.json).
