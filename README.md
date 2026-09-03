# EOH Controller - Phase 3

Phase 3 добавляет безопасный слой работы с жидкостями.

## Важно

Реальный `transferFluid()` выключен по умолчанию:

```lua
config.allow_fluid_transfer = false
```

При `false` клавиша `F` только показывает, что live transfer заблокирован.

Для контролируемого теста можно временно включить:

```lua
config.allow_fluid_transfer = true
```

Тестовая кнопка использует только один буфер Fluid Interface:

```lua
config.fill_test_amount = 16000
```

После операции контроллер считывает EOH ещё раз и показывает:

- запрошенный объём;
- реально перемещённый объём, который вернул transposer;
- объём EOH до операции;
- объём EOH после операции;
- наблюдаемую разницу.

Автоматический Production/Power Loop в Phase 3 ещё не включён.
