# EOH Controller - Phase 2

Phase 2 builds the real read-only EOH core for OpenComputers.

## Что уже работает

- Поиск Eye of Harmony по `gt_machine`.
- Поиск двух транспозеров по реальной схеме подключения.
- Чтение прямого API EOH: progress, max progress, active, work allowed, has work.
- Чтение и разбор `getSensorInformation()`.
- Чтение H2 / He / Raw Stellar Plasma.
- База T1-T9 из предоставленных рецептов.
- Расчёт требуемых жидкостей для Production / Power.
- Учет режима AA: без AA -> H2 + He; с AA -> Plasma.
- Расчёт дефицита с учётом `fluid_tolerance`.
- Проверка наличия источника жидкости в AE2 Fluid Interface.
- Предварительный план операций `transferFluid()`.
- GUI без полной очистки экрана при обычном обновлении.
- Логирование с ротацией около 1 MiB.

## Важно

Phase 2 работает в dry-run режиме:

`config.allow_fluid_transfer = false`

Поэтому никакая жидкость автоматически не перекачивается.

Масштабирование требований от overclock пока не применяется, пока не подтверждены реальные правила параметров EOH.

## Запуск

```text
lua /home/eoh/main.lua
```

Клавиши:

- R - повторный Scan
- C - расчёт требований (dry-run)
- S - сенсор EOH
- L - логи
- B - назад
- Q - выход

## Обновление

```text
lua /home/U.lua
```
