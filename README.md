# EOH Controller

HUB для управления Eye of Harmony через OpenComputers.

## Архитектура

`/home/autorun.lua` → `/home/hub/main.lua` → EOH Core.

`/home/eoh/main.lua` оставлен только как совместимый запускатель старых сценариев.

## Установка

Запустите `install_eoh.lua`. Установщик создаёт:

```text
/home/
├── autorun.lua
├── U.lua
├── update_manifest.lua
├── eoh/
│   ├── eoh_core.lua
│   ├── diagnose.lua
│   ├── main.lua
│   └── recipes.lua
├── hub/
│   ├── main.lua
│   ├── gui.lua
│   ├── registry.lua
│   └── setup.lua
└── lib/
    ├── config.lua
    ├── logger.lua
    └── settings.lua
```

## Важное

- Компоненты EOH и транспозеры **не назначаются случайно**. Если жидкость или контроллер не распознаны, настройка должна сообщить об этом.
- `sourceSide` и `targetSide` транспозера задаются в `/home/lib/config.lua` и используются при передаче.
- HUB является единственной основной точкой входа.
- Конфигурация нескольких EOH хранится в `/home/hub/registry.dat`.
- Логи: `/home/eoh/logs/eoh.log` и `/home/hub/logs/hub.log`.

## Запуск

После установки:

```text
lua /home/hub/main.lua
```

Автозапуск выполняется через `/home/autorun.lua`.

## Диагностика

Если EOH не находится, сначала проверьте:

1. Собран ли multiblock.
2. Подключён ли OpenComputers Adapter к нужному контроллеру.
3. Что `gt_machine` контроллера предоставляет `getWorkProgress`, `getWorkMaxProgress` и `getTankInfo` либо характерные строки sensor information.
4. Что транспозеры содержат нужную жидкость на настроенной `sourceSide`.

## Настройка сторон транспозера

По умолчанию источник — `north`, цель — `south`. Измените `/home/lib/config.lua`, если физическое подключение другое:

```lua
transposer = {
    transferRate = 1000,
    sourceSide = "north",
    targetSide = "south",
}
```

После изменения перезапустите HUB.
