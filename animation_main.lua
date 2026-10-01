
-- =========================================================================
-- FE UGC ANIMATION by in666ar V2.2.0
-- =========================================================================

local plrs = game:GetService("Players")
local as   = game:GetService("AssetService")
local aes  = game:GetService("AvatarEditorService")
local rs   = game:GetService("RunService")
local hs   = game:GetService("HttpService")
local cp   = game:GetService("ContentProvider")
local lp   = plrs.LocalPlayer

local m = {
    ["runanimation"]      = "run",
    ["climbanimation"]    = "climb",
    ["jumpanimation"]     = "jump",
    ["fallanimation"]     = "fall",
    ["idleanimation"]     = "idle",
    ["swimidleanimation"] = "swimidle",
    ["swimanimation"]     = "swim",
    ["walkanimation"]     = "walk"
}

local shortNames = {
    ["idleanimation"]     = "Idle",
    ["walkanimation"]     = "Walk",
    ["runanimation"]      = "Run",
    ["jumpanimation"]     = "Jump",
    ["fallanimation"]     = "Fall",
    ["climbanimation"]    = "Climb",
    ["swimidleanimation"] = "Swim Idle",
    ["swimanimation"]     = "Swim"
}

local buttonOrder = {
    "idleanimation", "walkanimation", "runanimation", "jumpanimation",
    "fallanimation", "climbanimation", "swimidleanimation", "swimanimation"
}

local slotDisplayOrder = {
    "Idle", "Walk", "Run", "Jump", "Fall", "Climb", "Swim Idle", "Swim"
}

local displayToSlot = {
    ["Idle"]      = "idleanimation",
    ["Walk"]      = "walkanimation",
    ["Run"]       = "runanimation",
    ["Jump"]      = "jumpanimation",
    ["Fall"]      = "fallanimation",
    ["Climb"]     = "climbanimation",
    ["Swim Idle"] = "swimidleanimation",
    ["Swim"]      = "swimanimation",
}

local ICO_DOT = "•"

local CACHE_FILE_NAME    = "animation_bundle_data_cache.json"
local ANIM_CACHE_URL     = "https://raw.githubusercontent.com/TribalFootball/TuffTeto/main/animation_bundle_data_cache.json"
local SEEN_BUNDLES_FILE  = "seen_anim_bundles_cache.json"
local EQUIPPED_FILE      = "FeUgcAnim.json"
local SAVED_BUNDLES_FILE = "FeUgcAnim_Bookmarks.json"

-- ============================================================
-- CACHE / FILE HELPERS
-- ============================================================

local assetCache, fileCache, seenBundles, equippedAnims = {}, {}, {}, {}
local savedBookmarks = {}

local function loadJSON(file)
    local ok, content = pcall(function()
        if isfile and not isfile(file) then return nil end
        return readfile(file)
    end)
    if ok and content then
        local suc, decoded = pcall(function() return hs:JSONDecode(content) end)
        return suc and decoded or {}
    end
    return {}
end

local function saveJSON(file, data)
    pcall(function() writefile(file, hs:JSONEncode(data)) end)
end

fileCache      = loadJSON(CACHE_FILE_NAME)
seenBundles    = loadJSON(SEEN_BUNDLES_FILE)
equippedAnims  = loadJSON(EQUIPPED_FILE)
savedBookmarks = loadJSON(SAVED_BUNDLES_FILE)

task.spawn(function()
    local ok, onlineContent = pcall(function() return game:HttpGet(ANIM_CACHE_URL) end)
    if ok and onlineContent then
        pcall(function()
            local onlineData = hs:JSONDecode(onlineContent)
            for k, v in pairs(onlineData) do
                if not fileCache[k] then fileCache[k] = v end
            end
            saveJSON(CACHE_FILE_NAME, fileCache)
        end)
    end
end)

-- ============================================================
-- ANIMATION CORE (preserved)
-- ============================================================

local function applySavedAnimations(char)
    if not char then return end
    local animate = char:WaitForChild("Animate", 5)
    local human   = char:WaitForChild("Humanoid", 5)
    if not animate or not human then return end
    for _, tr in ipairs(human:GetPlayingAnimationTracks()) do
        pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end)
    end
    animate.Disabled = true
    for slotType, animList in pairs(equippedAnims) do
        local fId = m[string.lower(slotType)]
        if fId then
            local folder = animate:FindFirstChild(fId)
            if folder then
                for _, o in ipairs(folder:GetChildren()) do
                    if o:IsA("Animation") then o:Destroy() end
                end
                for _, animData in ipairs(animList) do
                    local newAnim = Instance.new("Animation", folder)
                    newAnim.Name        = animData.Name
                    newAnim.AnimationId = animData.AnimationId
                end
            end
        end
    end
    task.wait(0.05)
    animate.Disabled = false
end

local function initAutoEquip(char)
    if not char then return end
    task.spawn(function()
        local animate = char:WaitForChild("Animate", 5)
        local human   = char:WaitForChild("Humanoid", 5)
        if animate and human then
            local idleFolder = animate:WaitForChild("idle", 5)
            if idleFolder then idleFolder:WaitForChild("Animation1", 3) end
            task.wait(0.1)
            applySavedAnimations(char)
        end
    end)
end

if lp.Character then initAutoEquip(lp.Character) end
lp.CharacterAdded:Connect(initAutoEquip)

local function get(id, bundleId, assetType)
    local stringId = tostring(id)
    if assetCache[stringId] then return assetCache[stringId] end
    if fileCache[stringId] then
        local reconstructed = {}
        for _, data in ipairs(fileCache[stringId]) do
            local anim = Instance.new("Animation")
            anim.Name, anim.AnimationId = data.Name, data.AnimationId
            table.insert(reconstructed, anim)
        end
        assetCache[stringId] = reconstructed
        return reconstructed
    end

    local t, serializableData = {}, {}
    local descProp = "IdleAnimation"
    local lowerType = assetType and string.lower(assetType) or ""

    if lowerType:find("idle") and not lowerType:find("swim") then descProp = "IdleAnimation"
    elseif lowerType:find("walk")  then descProp = "WalkAnimation"
    elseif lowerType:find("run")   then descProp = "RunAnimation"
    elseif lowerType:find("jump")  then descProp = "JumpAnimation"
    elseif lowerType:find("fall")  then descProp = "FallAnimation"
    elseif lowerType:find("climb") then descProp = "ClimbAnimation"
    elseif lowerType:find("swim")  then descProp = "SwimAnimation"
    end

    pcall(function()
        local desc = Instance.new("HumanoidDescription")
        desc[descProp] = tonumber(id)
        local dummy = plrs:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
        local animate = dummy:FindFirstChild("Animate")
        if animate then
            local targetFolders = (descProp == "SwimAnimation")
                and {"swim", "swimidle"}
                or {string.lower(string.gsub(descProp, "Animation", ""))}
            for _, folderName in ipairs(targetFolders) do
                local folder = animate:FindFirstChild(folderName)
                if folder then
                    for _, child in ipairs(folder:GetChildren()) do
                        if child:IsA("Animation") and child.AnimationId ~= "" then
                            local clone = child:Clone()
                            table.insert(t, clone)
                            table.insert(serializableData, {
                                Name = clone.Name,
                                AnimationId = clone.AnimationId,
                                BundleId = tostring(bundleId)
                            })
                        end
                    end
                end
            end
        end
        dummy:Destroy()
    end)

    if #t == 0 then
        pcall(function()
            local objs = game:GetObjects("rbxassetid://" .. stringId)
            if objs and #objs > 0 then
                local function processItem(item)
                    if item:IsA("Animation") then
                        table.insert(t, item:Clone())
                        table.insert(serializableData, {
                            Name = item.Name,
                            AnimationId = item.AnimationId,
                            BundleId = tostring(bundleId)
                        })
                    end
                end
                processItem(objs[1])
                for _, c in ipairs(objs[1]:GetDescendants()) do processItem(c) end
            end
        end)
    end

    assetCache[stringId] = t
    fileCache[stringId]  = serializableData
    saveJSON(CACHE_FILE_NAME, fileCache)
    return t
end

local function clearAssetCache(id)
    local stringId = tostring(id)
    assetCache[stringId], fileCache[stringId] = nil, nil
    saveJSON(CACHE_FILE_NAME, fileCache)
end

local function preloadAnimations(tracks)
    local i = {}
    for _, t in ipairs(tracks) do table.insert(i, t) end
    if #i > 0 then pcall(function() cp:PreloadAsync(i) end) end
end

local function getSpecificTrack(fetchedTracks, targetType)
    if not fetchedTracks or #fetchedTracks == 0 then return nil end
    if targetType == "swimidleanimation" then
        for _, tr in ipairs(fetchedTracks) do
            if string.lower(tr.Name):find("idle") then return tr end
        end
        return fetchedTracks[2] or fetchedTracks[1]
    elseif targetType == "swimanimation" then
        for _, tr in ipairs(fetchedTracks) do
            if string.lower(tr.Name) == "swim" then return tr end
        end
    end
    return fetchedTracks[1]
end

local function applyAnimationToCharacter(character, targetAnimations, slotType)
    if not character then return end
    local animate = character:WaitForChild("Animate", 5)
    local human   = character:FindFirstChildOfClass("Humanoid")
    if not animate or not human then return end
    for _, tr in ipairs(human:GetPlayingAnimationTracks()) do
        pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end)
    end
    animate.Disabled = true
    local cleanSlot = string.lower(slotType or "")
    local fId = m[cleanSlot]
    if fId then
        local folder = animate:FindFirstChild(fId)
        if folder then
            for _, o in ipairs(folder:GetChildren()) do
                if o:IsA("Animation") then o:Destroy() end
            end
            equippedAnims[cleanSlot] = {}
            for _, animAsset in ipairs(targetAnimations) do
                local newAnim = Instance.new("Animation", folder)
                newAnim.Name, newAnim.AnimationId = animAsset.Name, animAsset.AnimationId
                table.insert(equippedAnims[cleanSlot], {
                    Name = newAnim.Name,
                    AnimationId = newAnim.AnimationId
                })
            end
            saveJSON(EQUIPPED_FILE, equippedAnims)
        end
    end
    task.wait(0.05)
    animate.Disabled = false
end

local function applyBundleItemsToCharacter(items)
    if not lp.Character then return end
    local tLoad, tApply = {}, {}
    for _, lt in ipairs(buttonOrder) do
        local pay = items[lt]
        if pay then
            local t = get(pay.Id, nil, pay.AssetType)
            if lt == "idleanimation" then
                tApply[lt] = t
                for _, x in ipairs(t) do table.insert(tLoad, x) end
            else
                local spec = getSpecificTrack(t, lt)
                if spec then
                    tApply[lt] = {spec}
                    table.insert(tLoad, spec)
                end
            end
        end
    end
    preloadAnimations(tLoad)
    for slot, tracks in pairs(tApply) do
        applyAnimationToCharacter(lp.Character, tracks, slot)
    end
end

local function wearBundleQuickly(bundleId, onDone)
    task.spawn(function()
        local ok, res = pcall(function() return as:GetBundleDetailsAsync(bundleId) end)
        if ok and res and res.Items and lp.Character then
            local items = {}
            for _, item in ipairs(res.Items) do
                local lt = string.lower(item.AssetType or "")
                if lt == "swimanimation" then
                    items["swimanimation"]     = item
                    items["swimidleanimation"] = item
                elseif shortNames[lt] then
                    items[lt] = item
                end
            end
            applyBundleItemsToCharacter(items)
        end
        if onDone then onDone() end
    end)
end

local function toggleBookmark(bundleId, bundleName)
    local sId = tostring(bundleId)
    local nowSaved
    if savedBookmarks[sId] then
        savedBookmarks[sId] = nil
        nowSaved = false
    else
        savedBookmarks[sId] = {
            Id = bundleId, Name = bundleName, Fav = false, Time = tick()
        }
        nowSaved = true
    end
    saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
    return nowSaved
end

local function truncate(str, maxLen)
    if not str then return "" end
    if #str > maxLen then return str:sub(1, maxLen - 1) .. "…" end
    return str
end

-- ============================================================
-- SHARED STATE
-- ============================================================

local State = {
    ActiveBundleId     = nil,
    ActiveBundleName   = "None",
    ActiveBundleItems  = {},
    SelectedAnimSlot   = "idleanimation",

    DiscoverResults    = {},
    DiscoverPage       = 1,
    DiscoverCursor     = nil,
    DiscoverQuery      = "",
    DiscoverDebounce   = 0,

    SavedResults       = {},
    SavedPage          = 1,

    ItemsPerPage       = 6,

    Loading            = false,
    AnimationSpeed     = 1.0,

    PreviewTracks      = {},
    PreviewPanels      = {},
}

-- ============================================================
-- WINDOW
-- ============================================================

local Window = Fluent:CreateWindow({
    Title    = "FE UGC ANIMATION",
    SubTitle = "by in666ar V2.2.0",
    Size     = UDim2.fromOffset(660, 440),
    Theme    = "Blood Red",
    Acrylic  = false,
    Animated = true,
    MinimizeKey = Enum.KeyCode.LeftControl,
    Search   = false,
})

local AnimTab     = Window:AddTab({ Title = "Animations", Icon = "lucide/play" })
local SavedTab    = Window:AddTab({ Title = "Saved",      Icon = "lucide/bookmark" })
local SettingsTab = Window:AddTab({ Title = "Settings",   Icon = "lucide/settings" })

Window:SelectTab(1)

-- ============================================================
-- PREVIEW PANEL BUILDER
-- ============================================================

local function buildPreviewCharacter()
    local char = lp.Character or lp.CharacterAdded:Wait()
    if not char then return nil, nil end
    char.Archivable = true
    local clone = char:Clone()
    if not clone then return nil, nil end

    for _, c in ipairs(clone:GetChildren()) do
        if c:IsA("Script") or c:IsA("LocalScript") then c:Destroy() end
    end
    local human = clone:FindFirstChildOfClass("Humanoid")
    local root  = clone:FindFirstChild("HumanoidRootPart")
    if not human or not root then clone:Destroy(); return nil, nil end

    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    human.WalkSpeed  = 0
    human.JumpPower  = 0
    human.JumpHeight = 0

    clone:PivotTo(CFrame.new(0, 0, 0))
    local animator = human:FindFirstChildOfClass("Animator") or Instance.new("Animator", human)
    local af = clone:FindFirstChild("Animate")
    if af then af.Disabled = true end
    return clone, animator
end

local previewSpinAccum = 0
local spinConn = rs.RenderStepped:Connect(function(dt)
    previewSpinAccum = previewSpinAccum + math.rad(18 * dt)
    for _, panel in ipairs(State.PreviewPanels) do
        if panel.model and panel.model.Parent then
            panel.model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, previewSpinAccum, 0))
        end
    end
end)

local function stopAllPreviews()
    for _, panel in ipairs(State.PreviewPanels) do
        if panel.activeTrack then
            pcall(function() panel.activeTrack:Stop() end)
            panel.activeTrack = nil
        end
    end
end

local function playAllPreviews()
    if not State.ActiveBundleItems[State.SelectedAnimSlot] then
        for _, panel in ipairs(State.PreviewPanels) do
            if panel.infoLabel then
                panel.infoLabel:SetDesc("No animation selected")
            end
        end
        return
    end

    local payload = State.ActiveBundleItems[State.SelectedAnimSlot]
    local tracks  = get(payload.Id, nil, payload.AssetType)
    local spec    = getSpecificTrack(tracks, State.SelectedAnimSlot)
    if not spec then
        for _, panel in ipairs(State.PreviewPanels) do
            if panel.infoLabel then
                panel.infoLabel:SetDesc(truncate(State.ActiveBundleName, 30) .. " " .. ICO_DOT .. " Load failed")
            end
        end
        return
    end

    local speed = State.AnimationSpeed
    local statusText = truncate(State.ActiveBundleName, 30) .. " " .. ICO_DOT .. " " .. (shortNames[State.SelectedAnimSlot] or "Track")

    for _, panel in ipairs(State.PreviewPanels) do
        if panel.animator then
            if panel.activeTrack then
                pcall(function() panel.activeTrack:Stop() end)
            end
            local tr = panel.animator:LoadAnimation(spec)
            tr.Looped = true
            tr:Play()
            pcall(function() tr:AdjustSpeed(speed) end)
            panel.activeTrack = tr
        end
        if panel.infoLabel then panel.infoLabel:SetDesc(statusText) end
    end
end

local function refreshSaveButtons()
    local isSaved = State.ActiveBundleId and savedBookmarks[tostring(State.ActiveBundleId)] ~= nil
    for _, panel in ipairs(State.PreviewPanels) do
        if panel.saveBtn then
            if isSaved then panel.saveBtn:SetTitle("Saved ✓")
            else panel.saveBtn:SetTitle("Save to Saved") end
        end
    end
end

local function buildPreviewPanel(tab, opts)
    opts = opts or {}
    local section = tab:AddSection(opts.title or "Preview", "lucide/eye")

    local model, animator = buildPreviewCharacter()

    local panel = {
        model = model,
        animator = animator,
        activeTrack = nil,
        infoLabel = nil,
        saveBtn = nil,
    }

    if model then
        local cam = Instance.new("Camera")
        cam.CFrame = CFrame.new(Vector3.new(0, 1.4, 5), Vector3.new(0, 0.9, 0))
        local vp = section:AddViewport({
            Height      = 200,
            Object      = model,
            Camera      = cam,
            Focused     = true,
            Interactive = true,
            AspectRatio = "16:9",
        })
        task.defer(function() pcall(function() vp:Focus() end) end)
    else
        section:AddParagraph({
            Title   = "Preview Unavailable",
            Content = "Character not loaded yet. Respawn and try again.",
        })
    end

    section:AddDropdown("FUGCSlot_" .. tostring(#State.PreviewPanels), {
        Title    = "Animation Type",
        Description = "Choose which animation slot to preview",
        Icon     = "solar/widget-bold",
        Values   = slotDisplayOrder,
        Default  = "Idle",
        DropdownOutsideWindow = true,
        Callback = function(v)
            local slot = displayToSlot[v] or "idleanimation"
            State.SelectedAnimSlot = slot
            playAllPreviews()
        end,
    })

    panel.infoLabel = section:AddParagraph({
        Title   = "Status",
        Content = "No bundle selected",
    })

    local row1 = section:AddHGroup({ Gap = 6 })
    local r1a = row1:VGroup({ Gap = 0 })
    local r1b = row1:VGroup({ Gap = 0 })
    local r1c = row1:VGroup({ Gap = 0 })

    r1a:AddButton({
        Title = "Play",
        Icon  = "solar/play-bold",
        Callback = function() playAllPreviews() end,
    })
    r1b:AddButton({
        Title = "Stop",
        Icon  = "solar/stop-bold",
        Callback = function()
            stopAllPreviews()
            for _, p in ipairs(State.PreviewPanels) do
                if p.infoLabel then p.infoLabel:SetDesc("Stopped") end
            end
        end,
    })
    r1c:AddButton({
        Title = "Restart",
        Icon  = "solar/refresh-bold",
        Callback = function()
            stopAllPreviews()
            task.wait(0.05)
            playAllPreviews()
        end,
    })

    local row2 = section:AddHGroup({ Gap = 6 })
    local r2a = row2:VGroup({ Gap = 0 })
    local r2b = row2:VGroup({ Gap = 0 })

    r2a:AddButton({
        Title = "Wear Selected",
        Icon  = "solar/shirt-bold",
        Callback = function()
            if not State.ActiveBundleItems[State.SelectedAnimSlot] then
                Window:Notify({ Title = "FE UGC ANIMATION", Content = "No animation selected.", Duration = 3 })
                return
            end
            local tracks = get(State.ActiveBundleItems[State.SelectedAnimSlot].Id, nil,
                               State.ActiveBundleItems[State.SelectedAnimSlot].AssetType)
            local spec   = getSpecificTrack(tracks, State.SelectedAnimSlot)
            if spec and lp.Character then
                preloadAnimations({spec})
                applyAnimationToCharacter(lp.Character, {spec}, State.SelectedAnimSlot)
                Window:Notify({ Title = "FE UGC ANIMATION", Content = "Worn successfully.", Type = "Success", Duration = 2 })
            end
        end,
    })

    panel.saveBtn = r2b:AddButton({
        Title = "Save to Saved",
        Icon  = "solar/bookmark-bold",
        Callback = function()
            if not State.ActiveBundleId then return end
            local nowSaved = toggleBookmark(State.ActiveBundleId, State.ActiveBundleName)
            if nowSaved then
                Window:Notify({ Title = "FE UGC ANIMATION", Content = "Added to Saved.", Type = "Success", Duration = 2 })
            else
                Window:Notify({ Title = "FE UGC ANIMATION", Content = "Removed from Saved.", Duration = 2 })
            end
            refreshSaveButtons()
            renderSavedList()
        end,
    })

    table.insert(State.PreviewPanels, panel)
    return panel
end

-- ============================================================
-- ANIMATIONS TAB
-- ============================================================

local DiscoverPreview = buildPreviewPanel(AnimTab, { title = "Preview" })

local SearchSection = AnimTab:AddSection("Search", "lucide/search")

local debounceHandle
SearchSection:AddInput("FUGCDiscoverSearch", {
    Title       = "Search Animation",
    Description = "Partial matching supported (e.g. 'adid' → Adidas)",
    Placeholder = "Type to search...",
    Icon        = "solar/magnifer-bold",
    Callback    = function(text)
        State.DiscoverQuery = text or ""
        State.DiscoverDebounce = State.DiscoverDebounce + 1
        local myTok = State.DiscoverDebounce
        if debounceHandle then task.cancel(debounceHandle) end
        debounceHandle = task.delay(0.45, function()
            if myTok ~= State.DiscoverDebounce then return end
            State.DiscoverPage = 1
            runDiscoverSearch(State.DiscoverQuery)
        end)
    end,
})

local ResultsSection = AnimTab:AddSection("Results", "lucide/list")

local PaginationRow = ResultsSection:AddHGroup({ Gap = 6 })
local pPrevCol = PaginationRow:VGroup({ Gap = 0 })
local pLblCol  = PaginationRow:VGroup({ Gap = 0 })
local pNextCol = PaginationRow:VGroup({ Gap = 0 })

local pageInfoLbl = pLblCol:AddParagraph({ Title = "Page", Content = "1" })

pPrevCol:AddButton({
    Title = "← Back",
    Icon  = "solar/alt-arrow-left-bold",
    Callback = function()
        if State.DiscoverPage > 1 then
            State.DiscoverPage = State.DiscoverPage - 1
            renderDiscoverList()
        end
    end,
})

pNextCol:AddButton({
    Title = "Next →",
    Icon  = "solar/alt-arrow-right-bold",
    Callback = function()
        local total = #State.DiscoverResults
        if (State.DiscoverPage * State.ItemsPerPage) < total then
            State.DiscoverPage = State.DiscoverPage + 1
            renderDiscoverList()
        elseif State.DiscoverCursor and not State.DiscoverCursor.IsFinished then
            pageInfoLbl:SetDesc("Loading...")
            task.spawn(function()
                local ok = pcall(function() State.DiscoverCursor:AdvanceToNextPageAsync() end)
                if ok then
                    local nc = State.DiscoverCursor:GetCurrentPage()
                    for _, v in ipairs(nc) do
                        table.insert(State.DiscoverResults, v)
                    end
                    State.DiscoverPage = State.DiscoverPage + 1
                    renderDiscoverList()
                else
                    pageInfoLbl:SetDesc("Page " .. State.DiscoverPage)
                end
            end)
        end
    end,
})

local discoverListElems = {}
local function clearDiscoverList()
    for _, el in ipairs(discoverListElems) do
        pcall(function() el:Destroy() end)
    end
    discoverListElems = {}
end

local function addDiscoverCard(bundle)
    local el = ResultsSection:AddButton({
        Title       = truncate(bundle.Name or "Unknown", 32),
        Description = "ID: " .. tostring(bundle.Id or "?"),
        Icon        = "solar/play-circle-bold",
        Callback    = function()
            inspectBundle(bundle.Id, bundle.Name)
        end,
    })
    table.insert(discoverListElems, el)
end

function renderDiscoverList()
    clearDiscoverList()

    local list = State.DiscoverResults
    local total = #list

    if total == 0 then
        local empty = ResultsSection:AddParagraph({
            Title = "No Results",
            Content = (State.Loading and "Loading...") or "Try a different search query.",
        })
        table.insert(discoverListElems, empty)
        pageInfoLbl:SetDesc("Page 1")
        return
    end

    local s = (State.DiscoverPage - 1) * State.ItemsPerPage + 1
    local e = math.min(State.DiscoverPage * State.ItemsPerPage, total)

    for i = s, e do
        if list[i] then addDiscoverCard(list[i]) end
    end

    pageInfoLbl:SetDesc("Page " .. State.DiscoverPage .. " / " .. math.ceil(total / State.ItemsPerPage))
end

function runDiscoverSearch(query)
    State.DiscoverQuery = query or ""
    State.Loading = true

    if State.DiscoverPage == 1 then
        State.DiscoverResults = {}
        State.DiscoverCursor  = nil
    end

    if State.DiscoverPage == 1 then
        pageInfoLbl:SetDesc("Loading...")
        local p = CatalogSearchParams.new()
        p.SearchKeyword  = query or ""
        p.BundleTypes    = { Enum.BundleType.Animations }
        p.IncludeOffSale = true
        p.Limit          = 120
        pcall(function() p.CreatorType = Enum.CreatorType.User end)
        pcall(function() p.SalesTypeFilter = Enum.SalesTypeFilter.All end)
        pcall(function() p.SortType = Enum.SortType.Relevance end)

        task.spawn(function()
            local ok, pages = pcall(function() return aes:SearchCatalog(p) end)
            State.Loading = false
            if ok and pages then
                State.DiscoverCursor  = pages
                State.DiscoverResults = pages:GetCurrentPage()
                renderDiscoverList()
            else
                pageInfoLbl:SetDesc("Error")
                Window:Notify({
                    Title    = "FE UGC ANIMATION",
                    Content  = "Search failed. Please try again.",
                    Type     = "Error",
                    Duration = 4,
                })
            end
        end)
    else
        State.Loading = false
        renderDiscoverList()
    end
end

function inspectBundle(bundleId, bundleName)
    State.ActiveBundleId    = bundleId
    State.ActiveBundleName  = bundleName or "Unknown"
    State.ActiveBundleItems = {}

    for _, panel in ipairs(State.PreviewPanels) do
        if panel.infoLabel then
            panel.infoLabel:SetDesc(truncate(bundleName or "Unknown", 30) .. " " .. ICO_DOT .. " Loading...")
        end
    end

    task.spawn(function()
        local ok, res = pcall(function() return as:GetBundleDetailsAsync(bundleId) end)
        if not ok or not res or not res.Items then
            for _, panel in ipairs(State.PreviewPanels) do
                if panel.infoLabel then
                    panel.infoLabel:SetDesc(truncate(bundleName or "Unknown", 30) .. " " .. ICO_DOT .. " Load failed")
                end
            end
            return
        end

        for _, item in ipairs(res.Items) do
            local lt = string.lower(item.AssetType or "")
            if lt == "swimanimation" then
                State.ActiveBundleItems["swimanimation"]     = item
                State.ActiveBundleItems["swimidleanimation"] = item
            elseif shortNames[lt] then
                State.ActiveBundleItems[lt] = item
            end
        end

        local slotToPlay = State.SelectedAnimSlot
        if not State.ActiveBundleItems[slotToPlay] then
            slotToPlay = "idleanimation"
            for _, lt in ipairs(buttonOrder) do
                if State.ActiveBundleItems[lt] then slotToPlay = lt; break end
            end
            State.SelectedAnimSlot = slotToPlay
        end

        playAllPreviews()
        refreshSaveButtons()
    end)
end

-- ============================================================
-- SAVED TAB
-- ============================================================

local SavedPreview = buildPreviewPanel(SavedTab, { title = "Preview" })

local SavedSearchSection = SavedTab:AddSection("Saved Search", "lucide/search")
local savedDebounce
SavedSearchSection:AddInput("FUGCSavedSearch", {
    Title       = "Search Saved",
    Description = "Filter your bookmarks",
    Placeholder = "Type to filter...",
    Icon        = "solar/magnifer-bold",
    Callback    = function(text)
        local q = text or ""
        if savedDebounce then task.cancel(savedDebounce) end
        savedDebounce = task.delay(0.4, function()
            rebuildSavedList(q)
        end)
    end,
})

local SavedListSection = SavedTab:AddSection("Saved Animations", "lucide/bookmark")

local SavedPagRow = SavedListSection:AddHGroup({ Gap = 6 })
local sPrevCol = SavedPagRow:VGroup({ Gap = 0 })
local sLblCol  = SavedPagRow:VGroup({ Gap = 0 })
local sNextCol = SavedPagRow:VGroup({ Gap = 0 })

local savedPageInfo = sLblCol:AddParagraph({ Title = "Page", Content = "1" })

sPrevCol:AddButton({
    Title = "← Back",
    Icon  = "solar/alt-arrow-left-bold",
    Callback = function()
        if State.SavedPage > 1 then
            State.SavedPage = State.SavedPage - 1
            renderSavedList()
        end
    end,
})
sNextCol:AddButton({
    Title = "Next →",
    Icon  = "solar/alt-arrow-right-bold",
    Callback = function()
        local total = #State.SavedResults
        if (State.SavedPage * State.ItemsPerPage) < total then
            State.SavedPage = State.SavedPage + 1
            renderSavedList()
        end
    end,
})

local savedListElems = {}
local function clearSavedList()
    for _, el in ipairs(savedListElems) do
        pcall(function() el:Destroy() end)
    end
    savedListElems = {}
end

local function addSavedCard(bundle)
    local isFav = bundle.Fav
    local card = SavedListSection:AddButton({
        Title       = (isFav and "★ " or "☆ ") .. truncate(bundle.Name or "Unknown", 28),
        Description = "ID: " .. tostring(bundle.Id or "?"),
        Icon        = "solar/bookmark-bold",
        Callback    = function()
            inspectBundle(bundle.Id, bundle.Name)
        end,
    })
    table.insert(savedListElems, card)

    local actionRow = SavedListSection:AddHGroup({ Gap = 6 })
    local favCol    = actionRow:VGroup({ Gap = 0 })
    local removeCol = actionRow:VGroup({ Gap = 0 })

    favCol:AddButton({
        Title = isFav and "Unfavorite" or "Favorite",
        Icon  = "solar/star-bold",
        Callback = function()
            local sId = tostring(bundle.Id)
            if savedBookmarks[sId] then
                savedBookmarks[sId].Fav = not savedBookmarks[sId].Fav
                saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
                rebuildSavedList()
            end
        end,
    })

    removeCol:AddButton({
        Title = "Remove",
        Icon  = "solar/trash-bin-trash-bold",
        Callback = function()
            local sId = tostring(bundle.Id)
            if savedBookmarks[sId] then
                savedBookmarks[sId] = nil
                saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
                Window:Notify({ Title = "FE UGC ANIMATION", Content = "Removed from Saved.", Duration = 2 })
                rebuildSavedList()
                refreshSaveButtons()
            end
        end,
    })

    table.insert(savedListElems, actionRow.Frame)
end

function renderSavedList()
    clearSavedList()

    local list = State.SavedResults
    local total = #list

    if total == 0 then
        local empty = SavedListSection:AddParagraph({
            Title   = "No Saved Animations",
            Content = "Save animations from the Animations tab to see them here.",
        })
        table.insert(savedListElems, empty)
        savedPageInfo:SetDesc("Page 1")
        return
    end

    local s = (State.SavedPage - 1) * State.ItemsPerPage + 1
    local e = math.min(State.SavedPage * State.ItemsPerPage, total)

    for i = s, e do
        if list[i] then addSavedCard(list[i]) end
    end

    savedPageInfo:SetDesc("Page " .. State.SavedPage .. " / " .. math.ceil(total / State.ItemsPerPage))
end

function rebuildSavedList(filter)
    local q = string.lower(filter or "")
    State.SavedResults = {}
    for _, v in pairs(savedBookmarks) do
        if q == "" or string.lower(v.Name or ""):find(q, 1, true) then
            table.insert(State.SavedResults, v)
        end
    end
    table.sort(State.SavedResults, function(a, b)
        if a.Fav == b.Fav then return (a.Time or 0) > (b.Time or 0) end
        return a.Fav and not b.Fav
    end)
    State.SavedPage = 1
    renderSavedList()
end

-- ============================================================
-- SETTINGS TAB
-- ============================================================

local SettingsSection = SettingsTab:AddSection("Playback", "lucide/gauge")

SettingsSection:AddSlider("FUGCSpeed", {
    Title       = "Animation Speed",
    Description = "Adjust preview playback speed",
    Icon        = "solar/speedometer-bold",
    Min         = 0.25,
    Max         = 3.0,
    Rounding    = 2,
    Default     = 1.0,
    Callback    = function(v)
        State.AnimationSpeed = v
        for _, panel in ipairs(State.PreviewPanels) do
            if panel.activeTrack then
                pcall(function() panel.activeTrack:AdjustSpeed(v) end)
            end
        end
    end,
})

local StorageSection = SettingsTab:AddSection("Storage & Cache", "lucide/database")

StorageSection:AddButton({
    Title    = "Clear Animation Cache",
    Icon     = "solar/refresh-circle-bold",
    Callback = function()
        assetCache, fileCache = {}, {}
        saveJSON(CACHE_FILE_NAME, fileCache)
        Window:Notify({ Title = "FE UGC ANIMATION", Content = "Cache cleared.", Type = "Success", Duration = 2 })
    end,
})

StorageSection:AddButton({
    Title    = "Clear All Saved",
    Icon     = "solar/trash-bin-trash-bold",
    Callback = function()
        Window:Dialog({
            Title   = "Clear Saved?",
            Content = "This permanently removes all bookmarked animations.",
            Buttons = {
                { Title = "Clear", Callback = function()
                    savedBookmarks = {}
                    saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
                    rebuildSavedList()
                    refreshSaveButtons()
                    Window:Notify({ Title = "FE UGC ANIMATION", Content = "Cleared.", Type = "Success", Duration = 2 })
                end },
                { Title = "Cancel" },
            },
        })
    end,
})

local AppearanceSection = SettingsTab:AddSection("Appearance", "lucide/palette")

AppearanceSection:AddDropdown("FUGCSettingsTheme", {
    Title    = "Theme",
    Icon     = "solar/palette-bold",
    Values   = Fluent.Themes,
    Default  = Fluent.Theme or "Blood Red",
    DropdownOutsideWindow = true,
    IsManagerDropdown     = true,
    Callback = function(v)
        Fluent:SetTheme(v)
    end,
})

AppearanceSection:AddToggle("FUGCSettingsAnimated", {
    Title   = "Animated Shine",
    Default = true,
    Icon    = "solar/stars-bold",
    Callback = function(v)
        Fluent.ShineEnabled = v
        Fluent:SetTheme(Fluent.Theme)
    end,
})

-- ============================================================
-- INIT
-- ============================================================

task.defer(function()
    Window:Notify({
        Title      = "FE UGC ANIMATION",
        Content    = "by in666ar V2.2.0",
        SubContent = "Ready — loading catalog...",
        Type       = "Info",
        Duration   = 4,
    })
end)

rebuildSavedList()
task.spawn(function()
    task.wait(0.35)
    runDiscoverSearch("")
end)

-- ============================================================
-- CLEANUP
-- ============================================================

local function cleanup()
    if spinConn then
        pcall(function() spinConn:Disconnect() end)
        spinConn = nil
    end
    stopAllPreviews()
    for _, panel in ipairs(State.PreviewPanels) do
        if panel.model then
            pcall(function() panel.model:Destroy() end)
        end
    end
    State.PreviewPanels = {}
end

if Fluent.GUI then
    Fluent.GUI.Destroying:Connect(cleanup)
end

return true