#!/usr/bin/env lua
-- EOH Controller Installer
-- Автоматическая установка системы управления EOH

local fs = require("filesystem")
local shell = require("shell")

print("=== EOH Controller Installer ===")
print("Начинаю установку...")

-- Конфигурация установки
local INSTALL_ROOT = "/home"
local LIB_DIR = INSTALL_ROOT .. "/lib"
local EOH_DIR = INSTALL_ROOT .. "/eoh"
local HUB_DIR = INSTALL_ROOT .. "/hub"

-- Создаем директории
local dirs = {LIB_DIR, EOH_DIR, HUB_DIR}
for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
        print("Создаю директорию: " .. dir)
        fs.makeDirectory(dir)
    end
end

-- Структура файлов: {Откуда (относительно корня репо), Куда копировать}
local filesToInstall = {
    -- Библиотеки
    {"update_manifest.lua", LIB_DIR .. "/update_manifest.lua"},
    {"home/lib/logger.lua", LIB_DIR .. "/logger.lua"},
    
    -- EOH Core
    {"home/eoh/eoh_core.lua", EOH_DIR .. "/eoh_core.lua"},
    {"home/eoh/settings.lua", EOH_DIR .. "/settings.lua"},
    {"home/eoh/main.lua", EOH_DIR .. "/init.lua"},  -- main.lua используем как точку входа
    
    -- HUB
    {"home/hub/main.lua", HUB_DIR .. "/main.lua"},
    {"home/hub/registry.lua", HUB_DIR .. "/registry.lua"},
    {"home/hub/gui.lua", HUB_DIR .. "/gui.lua"},
    {"home/hub/setup.lua", HUB_DIR .. "/setup.lua"},  -- setup.lua для настройки
    
    -- Корневые файлы
    {"init.lua", INSTALL_ROOT .. "/init.lua"},
    {"autorun.lua", INSTALL_ROOT .. "/autorun.lua"},
    {"U.lua", "/U.lua"}
}

-- Примечание: Файл update_manifest.lua должен находиться в корне репозитория (/workspace/update_manifest.lua)

-- Проверяем наличие всех исходных файлов перед установкой
print("\nПроверка файлов...")
local missingFiles = {}
for _, fileMap in ipairs(filesToInstall) do
    local src = fileMap[1]
    if not fs.exists(src) then
        table.insert(missingFiles, src)
    end
end

if #missingFiles > 0 then
    print("\n[ERROR] Отсутствуют следующие файлы:")
    for _, file in ipairs(missingFiles) do
        print("  - " .. file)
    end
    print("\nУстановка невозможна. Проверьте структуру репозитория.")
    return
end

local successCount = 0
local failCount = 0

print("\nКопирование файлов:")
for _, fileMap in ipairs(filesToInstall) do
    local src = fileMap[1]
    local dst = fileMap[2]
    
    -- Проверяем существование исходного файла
    if not fs.exists(src) then
        print("  [ERROR] Файл не найден: " .. src)
        failCount = failCount + 1
    else
        -- Копируем файл
        local ok, err = fs.copy(src, dst)
        if ok then
            print("  [OK] " .. dst)
            successCount = successCount + 1
        else
            print("  [ERROR] Не удалось скопировать: " .. dst .. " (" .. tostring(err) .. ")")
            failCount = failCount + 1
        end
    end
end

print("\n=== Установка завершена ===")
print("Успешно: " .. successCount)
print("Ошибок: " .. failCount)

if failCount > 0 then
    print("\nВНИМАНИЕ: Некоторые файлы не были установлены!")
    print("Проверьте наличие всех файлов в репозитории.")
else
    print("\nВсе файлы установлены успешно!")
    print("Для запуска HUB выполните: lua /home/hub/main.lua")
    print("Для запуска одиночного EOH: lua /home/eoh/init.lua")
end
