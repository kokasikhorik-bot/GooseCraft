# Локальное сравнение CPU-пула с полным Map

GooseCraft 0.10.0, seed 12345, 81 logical chunk, одна камера, mesh-radius 2, окно 640×480.
Linux GCC 12.2, Mesa 22.3.6 lavapipe/Xvfb, network=none. По одному
последовательному сеансу 180 кадров, warmup 30, retained 150, без screenshot/readback.

| Метрика | Paged | Полный CPU Map |
| --- | ---: | ---: |
| CPU resident chunks | 49 | 81 |
| CPU block capacity, bytes | 200704 | 331776 |
| Active CPU block bytes | 200704 | 331776 |
| GPU mesh bytes | 327728 | 327728 |
| GPU mesh capacity, bytes | 503808 | 503808 |
| Startup, ms | 38.5127 | 37.2557 |
| Initial mesh, ms | 2.1241 | 2.1220 |
| CPU wall p50, ms | 2.0788 | 1.6271 |
| CPU wall p95, ms | 2.3418 | 2.0553 |
| CPU wall p99, ms | 3.1783 | 2.2722 |

Блоковый пул меньше на 131072 байта (128 КиБ, 39,51%). Это не весь RSS/VRAM.
В этом одном прогоне idle wall time не улучшился. I/O синхронное, lookup косвенный;
startup paged включает создание индекса/seed counts. Нельзя выводить устойчивый FPS
коэффициент из одного software-GPU прогона. При переходах preflight выполняет дополнительные
чтения; game_ns включает CPU admission и возможный checkpoint.

[Paged raw profile](profiles/pages-idle.json), [полный Map](profiles/cache-idle.json),
[счётчики/PNG hashes](render-results.json), [paging/экспорт](paging-results.json).
