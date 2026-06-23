-- Made by Bitto. https://gamebanana.com/members/1981980

function valuesplit(input) 
	local t={}
	for str in string.gmatch(input,"([^"..",".."]+)") do
		table.insert(t,str)
	end
	return t
end

local originalZoom = 1

function onCreatePost()
	originalZoom = getProperty("defaultCamZoom") -- initialize the zoom
	setProperty("camZooming", 1) -- make zooming possible even when no note has been hit.
end

local zoomTarget = 1.05

function onEvent(name,v1,v2)
	if name == "Bitto's zoom REL" then
		if v1 == "" then
			zoomTarget = originalZoom --anticrash
			debugPrint("Empty relative zoom in chart. setting zoom to " .. originalZoom)
		else
			zoomTarget = v1 * originalZoom
		end
		
		if v2 == '' then
			setProperty("defaultCamZoom", zoomTarget)
		else
			local table=stringSplit(v2, ',')
			local zoomduration = table[1]
			local tween = table[2]

			--debugPrint(zoomTarget .. ' ',zoomduration .. ' ',tween .. ' ')
			doTweenZoom('BittoZoom', 'camGame', zoomTarget, zoomduration * (crochet/1000), tween)
		end
	end
end

function onTweenCompleted(name)
    if name == 'BittoZoom' then
        setProperty("defaultCamZoom", originalZoom)
    end
end