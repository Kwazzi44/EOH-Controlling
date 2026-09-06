# EOH Controller

Контроллер Eye of Harmony для OpenComputers / GTNH.

## Что изменено в архитектуре

Приложение запускается одним входом:

```text
/home/autorun.lua
    ↓
/home/hub/main.lua
    ↓
/home/eoh/eoh_core.lua
    ├── context.lua
    ├── scanner.lua
    ├── runtime.lua
    ├── transposers.lua
    └── engine.lua
```

Каждый зарегистрированный EOH получает отдельный context. Адреса контроллера и transposer-ов не хранятся в одном глобальном состоянии.

## Безопасность обнаружения

Программа **не делает опасных догадок**:

- единственный `gt_machine` не считается EOH автоматически;
- при нескольких кандидатах EOH пользователь выбирает контроллер;
- несколько Hydrogen/Helium transposer-ов не выбираются случайно;
- неизвестный transposer можно выбрать вручную;
- один transposer нельзя назначить одновременно H2 и He;
- отсутствующий компонент остаётся `NOT CONFIGURED`, а не заменяется случайным адресом.

Для определения EOH используются имя машины, методы управления работой и sensor information. Это всё равно следует считать эвристикой: при неоднозначности Setup требует ручной выбор.

## Transposer

Для каждого transposer сохраняется его физическая `sourceSide`. Она может отличаться между устройствами.

`targetSide` по умолчанию берётся из конфигурации:

```lua
transposer = {
    sourceSide = "north",
    targetSide = "south",
    transferRate = 1000,
}
```

Сканер может определить сторону, на которой находится уникальная жидкость. Передача выполняется только между привязанным source и target.

Используется стандартный вызов OpenComputers:

```lua
transposer.transferFluid(sourceSide, targetSide, amount)
```

API возвращает `boolean, amount`; программа учитывает фактически перемещённый объём и умеет продолжать передачу до нужного количества.

## AUTO

Каждый EOH запускается отдельным OpenOS thread worker.

Worker периодически делает системный yield через `os.sleep`, поэтому GUI HUB не должен блокироваться во время ожидания рецепта.

AUTO при перезапуске компьютера восстанавливается из protected database, если `autoRestart = true`.

## Protected database

Код database обновляется вместе с программой, но сами пользовательские данные находятся отдельно:

```text
/home/eoh_data/database.dat
```

В защищённой базе хранятся только пользовательские данные:

- имя EOH;
- controller address;
- Hydrogen / Helium / Plasma transposer bindings;
- tier;
- planet;
- AA;
- overclocks 0–3;
- пользовательские operational settings.

Рецепты, код, runtime cache и логи **не** относятся к защищённым данным и могут обновляться.

Установщик удаляет и заново ставит свои программные каталоги, но `/home/eoh_data/` не трогает.

## Режимы

### Production

Использует Hydrogen и Helium.

### Production + Astral Arrays

Использует Plasma для AA-сценария.

### Deep Dark Energy

Использует production engine с tier 9.

## Установка

Самый простой способ — скачать установщик через встроенный `wget` OpenOS:

```text
wget -f https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main/install_eoh.lua /home/install_eoh.lua
lua /home/install_eoh.lua
```

После этого installer:

1. проверит подключение к GitHub;
2. сохранит/мигрирует пользовательскую базу;
3. скачает все необходимые файлы проекта;
4. проверит синтаксис загруженных Lua-файлов;
5. удалит только управляемые EOH-файлы;
6. установит новую версию;
7. перезагрузит компьютер.

## Обновление

`/home/U.lua` — загрузчик обновлений:

```text
/home/U.lua
    ↓
скачивает install_eoh.lua из GitHub/main
    ↓
запускает временный installer
    ↓
installer скачивает весь FILES из GitHub/main
    ↓
проверяет синтаксис
    ↓
заменяет программные файлы
    ↓
перезагружает компьютер
```

Запуск:

```text
lua /home/U.lua
```

`update_manifest.lua` является информационным манифестом. Фактический список файлов для обновления находится в `install_eoh.lua`.

## Диагностика

```text
lua /home/eoh/diagnose.lua
```

Диагностика безопасная: она только читает компоненты, sensor/tank information и protected database.

Если EOH не определяется, проверьте:

1. собран ли multiblock;
2. подключён ли OpenComputers Adapter к контроллеру;
3. что `gt_machine` предоставляет нужные методы;
4. что transposer подключён к нужным сторонам;
5. нет ли уже привязки этого transposer к другому EOH.

## Запуск HUB

```text
lua /home/hub/main.lua
```

Автозапуск выполняется через `/home/autorun.lua`.

## Логи

```text
/home/hub/logs/hub.log
/home/eoh/logs/eoh.log
```

## Версия

`20260906-2300`
