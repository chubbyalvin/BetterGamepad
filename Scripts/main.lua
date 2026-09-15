local PREFIX = "[BetterGamepad] "
local function fail(m) print(PREFIX .. "ERROR: " .. tostring(m)) end

if package == nil or type(package.loadlib) ~= "function" then
    fail("required Lua package functions unavailable")
    return
end

local function canOpen(path)
    if io == nil or type(io.open) ~= "function" then return false end
    local ok, file = pcall(io.open, path, "rb")
    if not ok or file == nil then return false end
    pcall(function() file:close() end)
    return true
end

local function looksLikeScriptsDir(dir)
    return type(dir) == "string" and canOpen(dir .. "\\BetterGamepad.dll") and canOpen(dir .. "\\config.lua")
end

local function resolveScriptDir()
    if debug ~= nil and type(debug.getinfo) == "function" then
        local ok, info = pcall(debug.getinfo, 1, "S")
        if ok and type(info) == "table" and type(info.source) == "string" then
            local source = info.source
            if source:sub(1, 1) == "@" then source = source:sub(2) end
            source = source:gsub("/", "\\")
            local dir = source:match("^(.+)\\[^\\]+$")
            if looksLikeScriptsDir(dir) then return dir end
        end
    end

    if type(package.path) == "string" then
        for entry in package.path:gmatch("[^;]+") do
            entry = entry:gsub("/", "\\")
            local dir = entry:match("^(.+)\\%?%.lua$")
            if looksLikeScriptsDir(dir) then return dir end
        end
    end

    return nil
end

local scriptDir = resolveScriptDir()
if scriptDir == nil then
    fail("unable to resolve Scripts directory")
    return
end

local config = { PartnerSkillTrigger = "Hold", PartnerSkillHoldMs = 350 }
if type(dofile) == "function" then
    local ok, value = pcall(dofile, scriptDir .. "\\config.lua")
    if ok and type(value) == "table" then config = value end
end

local partnerSkillTrigger = tostring(config.PartnerSkillTrigger or "Hold")
if partnerSkillTrigger ~= "Hold" and partnerSkillTrigger ~= "Tap" then partnerSkillTrigger = "Hold" end
local partnerSkillHoldMs = math.max(50, tonumber(config.PartnerSkillHoldMs) or 350)
local meleeTapReleaseMs = 60
local pollMs = 33
local dllPath = scriptDir .. "\\BetterGamepad.dll"

local function loadExport(name)
    local fn, err = package.loadlib(dllPath, name)
    if type(fn) ~= "function" then
        fail(name .. ": " .. tostring(err))
        return nil
    end
    return fn
end

local apply = loadExport("bettergamepad_apply")
local suppressReloadOn = loadExport("bettergamepad_suppress_reloadcoop_on")
local suppressReloadOff = loadExport("bettergamepad_suppress_reloadcoop_off")
local suppressRideOn = loadExport("bettergamepad_suppress_ridingskill3_on")
local multiRideOff = loadExport("bettergamepad_multi_ridingskill3_off")
local ridingSkill3 = loadExport("bettergamepad_riding_skill3")
local tapContext = loadExport("bettergamepad_tap_context")
local tapPartnerPriority = loadExport("bettergamepad_tap_partner_priority")
local partnerSkill = loadExport("bettergamepad_partner_skill")
local aimMultiActionPress = loadExport("bettergamepad_aim_multi_press")
local aimMultiActionRelease = loadExport("bettergamepad_aim_multi_release")
local finishMelee = loadExport("bettergamepad_finish_melee")

if not (apply and suppressReloadOn and suppressReloadOff and suppressRideOn and multiRideOff and ridingSkill3 and tapContext and tapPartnerPriority and partnerSkill and aimMultiActionPress and aimMultiActionRelease and finishMelee) then return end

local okApply, applyErr = pcall(apply)
if not okApply then
    fail(applyErr)
    return
end

-- Palworld can route Roll/Crouch/Descend into flying-mount Riding Skill 3.
-- Keep that vanilla Skill 3 path suppressed for the entire BetterGamepad session.
-- Deliberate Skill 3 use follows RidingSkill3_GamePad; when that action is on the
-- multi-action key, the existing multi-action behavior is preserved unchanged.
local okRideSuppress, rideSuppressErr = pcall(suppressRideOn)
if not okRideSuppress then
    fail(rideSuppressErr)
    return
end

local multiActionKeyName = "Gamepad_FaceButton_Left"
local multiActionKey = { KeyName = FName(multiActionKeyName) }
local leftTriggerKey = { KeyName = FName("Gamepad_LeftTrigger") }
local multiActionWasDown = false
local heldMs = 0
local holdTriggered = false
local aimMode = false
local meleeReleaseRemaining = -1
local lastReloadSuppress = nil
local lastRideUsesMulti = nil
local ridingSkill3Bindings = {}
local ridingSkill3TapMaxMs = 350

local function unwrap(value)
    if value == nil then return nil end
    local ok, got = pcall(function() return value:get() end)
    if ok and got ~= nil then return got end
    return value
end

local function safeGet(object, field)
    object = unwrap(object)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[field] end)
    if ok then return unwrap(value) end
    return nil
end

local function safeText(value)
    value = unwrap(value)
    if value == nil then return "" end
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    local ok, text = pcall(function() return value:ToString() end)
    if ok and text ~= nil then return tostring(text) end
    local okText, fallback = pcall(tostring, value)
    if not okText then return "" end
    fallback = tostring(fallback or "")
    return fallback:match("^FName%((.*)%)$") or fallback
end

local function keyText(value)
    value = unwrap(value)
    if value == nil then return "None" end
    local keyName = safeGet(value, "KeyName")
    if keyName ~= nil then
        local text = safeText(keyName)
        if text ~= "" then return text end
    end
    local text = safeText(value)
    if text == "" then return "None" end
    return text
end

local function getPalOptionSubsystem()
    if type(FindFirstOf) == "function" then
        for _, className in ipairs({ "BP_PalOptionSubsystem_C", "PalOptionSubsystem" }) do
            local ok, object = pcall(FindFirstOf, className)
            if ok and object ~= nil then return object end
        end
    end
    if type(FindAllOf) == "function" then
        for _, className in ipairs({ "BP_PalOptionSubsystem_C", "PalOptionSubsystem" }) do
            local ok, objects = pcall(FindAllOf, className)
            if ok and type(objects) == "table" then
                for _, object in pairs(objects) do
                    if object ~= nil then return object end
                end
            end
        end
    end
    return nil
end

local function findActionKeys(settings, wanted)
    local mappings = safeGet(settings, "GamePadActionMappings")
    if type(mappings) ~= "table" then return nil, nil end
    for actionParam, valueParam in pairs(mappings) do
        if safeText(actionParam) == wanted then
            return keyText(safeGet(valueParam, "MainKey")), keyText(safeGet(valueParam, "SecondaryKey"))
        end
    end
    return nil, nil
end

local function actionUsesMultiActionKey(main, secondary)
    return main == multiActionKeyName or secondary == multiActionKeyName
end

local function usableKeyName(name)
    return type(name) == "string" and name ~= "" and name ~= "None"
end

local function call(fn)
    local ok, err = pcall(fn)
    if not ok then fail(err) end
end

local function refreshNativeSuppression()
    local subsystem = getPalOptionSubsystem()
    if subsystem == nil then return false end
    local settings = nil
    local ok = pcall(function() settings = unwrap(subsystem:GetKeyConfigSettings()) end)
    if not ok or type(settings) ~= "table" then return false end

    local reloadMain, reloadSecondary = findActionKeys(settings, "ReloadAndCoop")
    local suppressReload = actionUsesMultiActionKey(reloadMain, reloadSecondary)
    if suppressReload ~= lastReloadSuppress then
        lastReloadSuppress = suppressReload
        call(suppressReload and suppressReloadOn or suppressReloadOff)
    end

    local rideMain, rideSecondary = findActionKeys(settings, "RidingSkill3_GamePad")
    local rollMain, rollSecondary = findActionKeys(settings, "RollingAndCrouch")
    local rideNames = {}
    local seen = {}
    for _, name in ipairs({ rideMain, rideSecondary }) do
        if usableKeyName(name) and not seen[name] then
            seen[name] = true
            rideNames[#rideNames + 1] = name
        end
    end

    -- If the action cannot be read, preserve the already-tested multi-action behavior.
    local rideUsesMulti = (#rideNames == 0)
    local newBindings = {}
    for _, name in ipairs(rideNames) do
        if name == multiActionKeyName then
            rideUsesMulti = true
        else
            newBindings[#newBindings + 1] = {
                name = name,
                key = { KeyName = FName(name) },
                sharedWithRoll = (name == rollMain or name == rollSecondary),
                wasDown = false,
                heldMs = 0,
                ignoreUntilRelease = true,
            }
        end
    end
    ridingSkill3Bindings = newBindings

    if rideUsesMulti ~= lastRideUsesMulti then
        lastRideUsesMulti = rideUsesMulti
        -- suppressRideOn also enables Skill 3 inside the existing multi-action tap paths.
        -- multiRideOff disables only that deliberate multi-key Skill 3 branch; the
        -- vanilla Roll/Crouch/Descend suppression remains enabled.
        call(rideUsesMulti and suppressRideOn or multiRideOff)
    end
    return true
end

local cachedPc = nil
local acquireRemaining = 0
local reacquireDelayMs = 0
local ignoreMultiActionUntilRelease = false
local shuttingDown = false

local function resolvePlayerController()
    if UEHelpers ~= nil and type(UEHelpers.GetPlayerController) == "function" then
        local ok, pc = pcall(function() return UEHelpers:GetPlayerController() end)
        if ok and pc ~= nil then return pc end
    end
    if type(FindFirstOf) == "function" then
        local ok, pc = pcall(FindFirstOf, "PalPlayerController")
        if ok and pc ~= nil then return pc end
    end
    return nil
end

local function controllerFullName(pc)
    local ok, value = pcall(function() return pc:GetFullName() end)
    if not ok or value == nil then return "" end
    return tostring(value)
end

local function resolveGameplayController()
    local pc = resolvePlayerController()
    if pc == nil then return nil end
    local name = controllerFullName(pc)
    if name == "" then return nil end
    if name:find("PL_Title", 1, true) or name:find("PL_Login", 1, true) or name:find("PL_PPSplash", 1, true) then return nil end
    return pc
end

local function inputKeyDown(pc, key)
    local ok, down = pcall(function() return pc:IsInputKeyDown(key) end)
    if not ok then return nil end
    return down == true
end

local function multiActionDown(pc)
    return inputKeyDown(pc, multiActionKey)
end

local function leftTriggerDown(pc)
    local ok, value = pcall(function() return pc:GetInputAnalogKeyState(leftTriggerKey) end)
    if not ok then return nil end
    return math.abs(tonumber(value) or 0) >= 0.50
end

local function inputKeyHeldMs(pc, key)
    local ok, seconds = pcall(function() return pc:GetInputKeyTimeDown(key) end)
    if not ok then return nil end
    seconds = tonumber(seconds)
    if seconds == nil or seconds < 0 then return nil end
    return seconds * 1000
end

local function keyHeldMs(pc)
    return inputKeyHeldMs(pc, multiActionKey)
end

local function tickRidingSkill3(pc)
    for _, binding in ipairs(ridingSkill3Bindings) do
        local down = inputKeyDown(pc, binding.key)
        if down == nil then return false end

        if binding.ignoreUntilRelease then
            if not down then
                binding.ignoreUntilRelease = false
                binding.wasDown = false
                binding.heldMs = 0
            else
                binding.wasDown = true
            end
        elseif binding.sharedWithRoll then
            -- When Skill 3 shares Roll/Crouch/Descend, preserve the useful vanilla
            -- distinction: short tap = Skill 3, hold = Roll/Crouch/Descend only.
            if down and not binding.wasDown then
                binding.heldMs = inputKeyHeldMs(pc, binding.key) or 0
            elseif down then
                binding.heldMs = inputKeyHeldMs(pc, binding.key) or binding.heldMs
            elseif binding.wasDown then
                if binding.heldMs < ridingSkill3TapMaxMs then call(ridingSkill3) end
                binding.heldMs = 0
            end
            binding.wasDown = down
        else
            -- On a dedicated Skill 3 key there is no hold conflict, so fire on press.
            if down and not binding.wasDown then call(ridingSkill3) end
            binding.wasDown = down
        end
    end
    return true
end

local function normalTap()
    if partnerSkillTrigger == "Tap" then
        call(tapPartnerPriority)
    else
        call(tapContext)
        meleeReleaseRemaining = meleeTapReleaseMs
    end
end

local function resetInputState()
    multiActionWasDown = false
    heldMs = 0
    holdTriggered = false
    aimMode = false
end

local function tick()
    if shuttingDown then return end

    if meleeReleaseRemaining >= 0 then
        meleeReleaseRemaining = meleeReleaseRemaining - pollMs
        if meleeReleaseRemaining <= 0 then
            meleeReleaseRemaining = -1
            call(finishMelee)
        end
    end

    local pc = cachedPc
    if pc == nil then
        if reacquireDelayMs > 0 then
            reacquireDelayMs = math.max(0, reacquireDelayMs - pollMs)
            return
        end
        acquireRemaining = acquireRemaining - pollMs
        if acquireRemaining <= 0 then
            acquireRemaining = 1000
            local candidate = resolveGameplayController()
            if candidate ~= nil then
                cachedPc = candidate
                refreshNativeSuppression()
                local initialDown = multiActionDown(candidate)
                if initialDown == true then ignoreMultiActionUntilRelease = true end
            end
        end
        return
    end

    local down = multiActionDown(pc)
    if down == nil then
        if multiActionWasDown or holdTriggered or aimMode then ignoreMultiActionUntilRelease = true end
        cachedPc = nil
        resetInputState()
        meleeReleaseRemaining = -1
        acquireRemaining = 500
        return
    end

    if not tickRidingSkill3(pc) then
        cachedPc = nil
        resetInputState()
        meleeReleaseRemaining = -1
        acquireRemaining = 500
        return
    end

    if ignoreMultiActionUntilRelease then
        if not down then
            ignoreMultiActionUntilRelease = false
            resetInputState()
        else
            multiActionWasDown = true
        end
        return
    end

    if down and not multiActionWasDown then
        if meleeReleaseRemaining >= 0 then
            meleeReleaseRemaining = -1
            call(finishMelee)
        end
        heldMs = keyHeldMs(pc) or 0
        holdTriggered = false
        local aim = leftTriggerDown(pc)
        if aim == nil then
            resetInputState()
            return
        end
        aimMode = aim
        if aimMode then call(aimMultiActionPress) end
    elseif down then
        heldMs = keyHeldMs(pc) or heldMs
        local aim = leftTriggerDown(pc)
        if aim == nil then
            resetInputState()
            return
        end
        if aim and not aimMode and not holdTriggered then
            aimMode = true
            call(aimMultiActionPress)
        end
        if not aimMode and partnerSkillTrigger == "Hold" and not holdTriggered and heldMs >= partnerSkillHoldMs then
            holdTriggered = true
            call(partnerSkill)
        end
    elseif multiActionWasDown then
        if aimMode then
            call(aimMultiActionRelease)
        elseif not holdTriggered then
            normalTap()
        end
        heldMs = 0
        holdTriggered = false
        aimMode = false
    end

    multiActionWasDown = down
end

local function clearController()
    cachedPc = nil
    resetInputState()
    meleeReleaseRemaining = -1
    ignoreMultiActionUntilRelease = false
    for _, binding in ipairs(ridingSkill3Bindings) do
        binding.wasDown = false
        binding.heldMs = 0
        binding.ignoreUntilRelease = true
    end
end

local function onLeaveWorld()
    clearController()
    reacquireDelayMs = 5000
    acquireRemaining = 1000
end

local function onShutdown()
    shuttingDown = true
    clearController()
end

local function onKeyConfigChanged()
    if cachedPc == nil or shuttingDown then return end
    refreshNativeSuppression()
end

local function onLoadMapPre()
    clearController()
    reacquireDelayMs = 1000
    acquireRemaining = 1000
end

if type(RegisterLoadMapPreHook) == "function" then
    local ok, err = pcall(RegisterLoadMapPreHook, onLoadMapPre)
    if not ok then fail("LoadMap pre-hook: " .. tostring(err)) end
else
    fail("RegisterLoadMapPreHook unavailable")
    return
end

if type(RegisterHook) == "function" then
    pcall(RegisterHook, "/Script/Pal.PalPlayerInput:OnChangeKeyConfig", onKeyConfigChanged)
    pcall(RegisterHook, "/Script/Engine.GameInstance:ReceiveShutdown", onShutdown)
end

if type(LoopInGameThreadWithDelay) == "function" then
    LoopInGameThreadWithDelay(pollMs, tick)
elseif type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
    LoopAsync(pollMs, function()
        ExecuteInGameThread(tick)
        return false
    end)
else
    fail("no supported recurring game-thread loop API")
    return
end

print(PREFIX .. "v1.0 loaded")
