-- now supports per-character texture: true = default (3d for dad, 3d2 for bf), or string like '3d3' for specific variant
local threeDCharacters = {
    ['shaggy'] = '3d',
    ['shaggy-3d'] = '3d',
    ['shaggy-god'] = '3d',
    ['bf'] = '3d2',
    ['bf2'] = '3d2',
    ['eevee'] = '3d2'
}

local dad3D = false -- will hold texture string or false
local bf3D = false

local lastDad = ''
local lastBF = ''

local function get3DTextureForChar(char, isDadSide)
    local v = threeDCharacters[string.lower(char or '')]
    if v == nil then return false end
    if v == true then return isDadSide and '3d' or '3d2' end
    if type(v) == 'string' then return v end
    return false
end
local function is3DCharacter(char)
    return get3DTextureForChar(char, true) ~= false
end

local function disableRGBForGroup(group, length)
    for i = 0, length - 1 do
        -- disable RGB shader if present
        pcall(function() setPropertyFromGroup(group, i, 'rgbShader.enabled', false) end)
        -- also reset color to white to prevent tint
    end
end

local function isPlain3D(tex) return tex == '3d' end

local function updateStrums()
    local total = getProperty('strumLineNotes.length')
    local split = math.floor(total / 2)

    for i = 0, total - 1 do
        local isOpponent = i < split
        local texture

        if isOpponent then
            texture = dad3D or ''
        else
            texture = bf3D or ''
        end

        local currentTexture = getPropertyFromGroup('strumLineNotes', i, 'texture')

        if currentTexture ~= texture then
            setPropertyFromGroup('strumLineNotes', i, 'texture', texture)
        end

        -- only for plain '3d' (not 3d2/3d3/etc) set is3DNoteTexture + antialiasing false; keep animations for numbered
        if isPlain3D(texture) then
            pcall(function() setPropertyFromGroup('strumLineNotes', i, 'is3DNoteTexture', true) end)
            setPropertyFromGroup('strumLineNotes', i, 'antialiasing', false)
        else
            pcall(function() setPropertyFromGroup('strumLineNotes', i, 'is3DNoteTexture', false) end)
            if texture ~= '' then setPropertyFromGroup('strumLineNotes', i, 'antialiasing', true) end
        end

        -- disable strum note RGB
        pcall(function() setPropertyFromGroup('strumLineNotes', i, 'rgbShader.enabled', false) end)
        pcall(function() setPropertyFromGroup('strumLineNotes', i, 'useRGBShader', false) end)
    end
end

local function updateUnspawnNotes()
    for i = 0, getProperty('unspawnNotes.length') - 1 do
        local mustPress = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        local tex = ''
        if mustPress then
            tex = bf3D or ''
            setPropertyFromGroup('unspawnNotes', i, 'texture', tex)
        else
            tex = dad3D or ''
            setPropertyFromGroup('unspawnNotes', i, 'texture', tex)
        end
        -- only plain '3d' gets is3DNoteTexture + antialiasing false
        if isPlain3D(tex) then
            pcall(function() setPropertyFromGroup('unspawnNotes', i, 'is3DNoteTexture', true) end)
            setPropertyFromGroup('unspawnNotes', i, 'antialiasing', false)
        else
            pcall(function() setPropertyFromGroup('unspawnNotes', i, 'is3DNoteTexture', false) end)
            if tex ~= '' then setPropertyFromGroup('unspawnNotes', i, 'antialiasing', true) end
        end
        -- disable note RGB
        pcall(function() setPropertyFromGroup('unspawnNotes', i, 'rgbShader.enabled', false) end)
        pcall(function() setPropertyFromGroup('unspawnNotes', i, 'useRGBShader', false) end)
    end
    -- also handle spawned notes (keep animations for numbered 3d)
    for i = 0, getProperty('notes.length') - 1 do
        local tex = getPropertyFromGroup('notes', i, 'texture') or ''
        if isPlain3D(tex) then
            pcall(function() setPropertyFromGroup('notes', i, 'is3DNoteTexture', true) end)
            setPropertyFromGroup('notes', i, 'antialiasing', false)
        else
            pcall(function() setPropertyFromGroup('notes', i, 'is3DNoteTexture', false) end)
            if tex:match('^3d%d+$') then setPropertyFromGroup('notes', i, 'antialiasing', true) end
        end
        pcall(function() setPropertyFromGroup('notes', i, 'rgbShader.enabled', false) end)
        pcall(function() setPropertyFromGroup('notes', i, 'useRGBShader', false) end)
    end
end

local function updateStrumPositions()
    local total = getProperty('strumLineNotes.length')
    local split = math.floor(total / 2)

    local dadCenter = 412
    local bfCenter = 932

    for i = 0, total - 1 do
        local isOpponent = i < split

        if isOpponent then
            local sideIndex = i
            local x = dadCenter + ((sideIndex - (split - 1) / 2) * noteSpacing)

            setPropertyFromGroup('strumLineNotes', i, 'x', x)
        else
            local sideIndex = i - split
            local playerKeys = total - split

            local x = bfCenter + ((sideIndex - (playerKeys - 1) / 2) * noteSpacing)

            setPropertyFromGroup('strumLineNotes', i, 'x', x)
            setPropertyFromGroup('strumLineNotes', i, 'antialiasing', true)
        end
    end
end

local function refreshNotes()
    dad3D = get3DTextureForChar(getProperty('dad.curCharacter'), true)
    bf3D = get3DTextureForChar(getProperty('boyfriend.curCharacter'), false)

    updateStrums()
    updateUnspawnNotes()
    updateStrumPositions()
end

function onCreatePost()
    -- disable song-wide note RGB (engine flag)
    pcall(function() setProperty('SONG.disableNoteRGB', true) end)
    pcall(function() setPropertyFromClass('PlayState', 'SONG.disableNoteRGB', true) end)
    lastDad = getProperty('dad.curCharacter')
    lastBF = getProperty('boyfriend.curCharacter')
    refreshNotes()
    -- ensure strum/notes RGB off immediately
    disableRGBForGroup('strumLineNotes', getProperty('strumLineNotes.length'))
    disableRGBForGroup('unspawnNotes', getProperty('unspawnNotes.length'))
    disableRGBForGroup('notes', getProperty('notes.length'))
end

function onUpdatePost()
    local dad = getProperty('dad.curCharacter')
    local bf = getProperty('boyfriend.curCharacter')

    if dad ~= lastDad or bf ~= lastBF then
        lastDad = dad
        lastBF = bf
        refreshNotes()
    end
    -- keep RGB disabled every frame (covers new spawned notes)
    disableRGBForGroup('notes', getProperty('notes.length'))
    disableRGBForGroup('strumLineNotes', getProperty('strumLineNotes.length'))
end

function onEvent(name, v1, v2)
    if name == 'Set Key Count' then
        runTimer('refresh3DNotes', 0.05)
    end
end

function onTimerCompleted(tag)
    if tag == 'refresh3DNotes' then
        refreshNotes()
    end
end
