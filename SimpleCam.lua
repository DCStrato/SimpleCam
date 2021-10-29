obs = obslua
bit = require("bit")

SourceChanged = false

source_data = {}
source_def = {}
source_def.id = "Camera_Preset2"
source_def.type = OBS_SOURCE_TYPE_INPUT;
source_def.output_flags = bit.bor(obs.OBS_SOURCE_CUSTOM_DRAW )
Presets = {}

PROP_Preset_Labels = ""
PROP_Preset_Marker = ""
markDuplicates = true
inTimer = false
inRename = false
inPreset = false
inLoad = false
inSwap = false

local function getTempPath()
    local directorySeperator = package.config:match("([^\n]*)\n?")
    local exampleTempFilePath = os.tmpname()  -- create a temp file to get path
    
    -- remove generated temp file
    pcall(os.remove, exampleTempFilePath)  --remove file

    local seperatorIdx = exampleTempFilePath:reverse():find(directorySeperator)
    local tempPathStringLength = #exampleTempFilePath - seperatorIdx

    return exampleTempFilePath:sub(1, tempPathStringLength)  --return only the path
end	

function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
  table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

function script_update(settings)
    PROP_Preset_Labels = getTempPath() .. "/SCPresets.inf"
	PROP_Preset_Marker = getTempPath() .. "/SCPresets.dat"
end



function loadPresets()
-- Read Presets.inf file for Camera and Preset Names
	if inLoad then return end
    inLoad = true
	local f = io.open(getTempPath() .. "/SCPresets.inf", "r")
	if (f~=nil) then
	   local str = f:read("*all")
	   Presets = { }
	   Presets = str:split(",")
	   f:close()
	end
	SourceChanged = false
	inLoad = false
end
function DoSourceSwap()
	if inSwap then return end
	inSwap = true
	Swaps = {}
	local f = io.open(getTempPath() .. "/SCPresetSwap.inf", "r")
	if (f~=nil) then
	   local str = f:read("*all")
	   Swaps = str:split(",")
	   f:close()
	end
	local ndx = ""
	local sources = obs.obs_enum_sources()
	for _, source in pairs(sources) do
		local source_id = obs.obs_source_get_id(source)
		if source_id == "Camera_Preset2" then
			local c_name = obs.obs_source_get_name(source)
			local settings = obs.obs_source_get_settings(source)
			local cam = tonumber(obs.obs_data_get_string(settings, "camera"))
			local index = obs.obs_data_get_string(settings, "index")
			obs.obs_data_set_string(settings, "index", i)
			if (cam ~= nil) then 
				if cam == Swaps[1] then -- only work on target camera
					if obs.obs_data_get_string(settings, "preset") ~= "0" then 
						local ndx = obs.obs_data_get_string(settings, "preset") 
						if ndx == Swaps[2] then
						   obs.obs_data_set_string(settings, "preset",Swaps[3]) 
						elseif ndx == Swaps[3] then
						   obs.obs_data_set_string(settings, "preset",Swaps[2])  
						end
					end
				end
			end
			obs.obs_data_release(settings)	
		end
	end
	obs.source_list_release(sources)
	inSwap = false
end
function rename_presets()
	if inRename then return end
	inRename = true
	if Presets[2] ~= nil then 
	local sources = obs.obs_enum_sources()
	if (sources ~= nil) and (SourceChanged == false) then
		-- count and index sources
		local t = 1
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_id(source)
			if source_id == "Camera_Preset2" then
				local settings = obs.obs_source_get_settings(source)
				obs.obs_data_set_string(settings, "index", #sources-t+1)
				t = t + 1
				obs.obs_data_release(settings)	
			end
		end
		-- Count Duplicates
		local preset_items = {}
		local scenes = obs.obs_frontend_get_scenes()
		if scenes ~= nil then
			for _, scenesource in ipairs(scenes) do
				local scene = obs.obs_scene_from_source(scenesource)
				local scene_name = obs.obs_source_get_name(scenesource)
				local scene_items = obs.obs_scene_enum_items(scene)
				if scene_items ~= nil then
					for _, scene_item in ipairs(scene_items) do
						local source = obs.obs_sceneitem_get_source(scene_item)
						local source_id = obs.obs_source_get_unversioned_id(source)
						if source_id == "Camera_Preset2" then
							local settings = obs.obs_source_get_settings(source)
							local index = obs.obs_data_get_string(settings, "index")
							if preset_items[index] == nil then
								preset_items[index] = "1"
							else
								preset_items[index] = "*"
							end
							obs.obs_data_release(settings)	
						end
					end
				end
				obs.sceneitem_list_release(scene_items)
			end
			obs.source_list_release(scenes)
		end
		-- Enumerate Presets with Descriptive and Unique Names
		local i = 1
		for _, source in pairs(sources) do
			local source_id = obs.obs_source_get_id(source)
			if source_id == "Camera_Preset2" then
				local c_name = obs.obs_source_get_name(source)
				local settings = obs.obs_source_get_settings(source)
				local cam = tonumber(obs.obs_data_get_string(settings, "camera"))
				local index = obs.obs_data_get_string(settings, "index")
				obs.obs_data_set_string(settings, "index", i)
				if (cam ~= nil) then 
					local name = t-i .. ". Move " .. Presets[cam] .. " to <i>Home</i>"
					local xname = i .. ". Move " .. Presets[cam] .. " to <i>Home</i>"
					if obs.obs_data_get_string(settings, "preset") ~= "0" then
						local ndx = tonumber(obs.obs_data_get_string(settings, "preset")) + (14 * (cam - 1))
						name = t-i .. ". Move " .. Presets[cam] .. " to <i><b>" .. Presets[ndx+5] .. "</b></i>" 
						xname = i .. ". Move " .. Presets[cam] .. " to <i><b>" .. Presets[ndx+5] .. "</b></i>" 
					end
					-- Mark Duplicates
					if index ~= nil then
						if preset_items[index] == "*" then
							xname =  "<span style=\"color:#FF6050;\">" .. xname .. " * </span>"
							name =  "<span style=\"color:#FF6050;\">" .. name .. " * </span>"
						end	
						if (c_name ~= name) then
							obs.obs_source_set_name(source, name)
						end	
					end
					i = i + 1
				end
				obs.obs_data_release(settings)	
			end
		end
	end
	obs.source_list_release(sources)
	end
	inRename = false
end

function timer_callback()
	if inTimer then return end
	inTimer = true
    local fname = getTempPath() .. "/SCPresets"
    local x = io.open(fname .. ".dat", "r") 
	if (x ~= nil) then
		x:close()
	    os.remove(fname .. ".inf") 					   -- Delete old Preset.Inf file
		os.rename(fname .. ".dat", fname .. ".inf")  -- Rename Preset.Dat to Preset.Inf
		loadPresets()	
		SourceChanged = true
	end
	if not SourceChanged then
		local fname = getTempPath() .. "/SCPresetSwap"
		local x = io.open(fname .. ".dat", "r") 
		if (x ~= nil) then
			x:close()
			os.remove(fname .. ".inf") 					   -- Delete old Preset.Inf file
			os.rename(fname .. ".dat", fname .. ".inf")  -- Rename Preset.Dat to Preset.Inf
			DoSourceSwap()	
		end
		SourceChanged = true
	end
	if SourceChanged then
 	   SourceChanged = false
	   rename_presets()									   -- ReSync any Source Names with the New 
    end
	inTimer = false
end

function on_event(event)
	
	--rename_presets()

end


function script_load(settings)
	--obs.obs_frontend_add_event_callback(on_event)
	obs.timer_add(timer_callback, 8000)
end

function script_update(settings)
--	markPreviews = obs.obs_data_get_bool(settings, "markPreviewScenes")
	--markDuplicates = obs.obs_data_get_bool(settings, "markRefSources")
end

function script_properties()
--	local props = obs.obs_properties_create()
--	obs.obs_properties_add_bool(props,"markRefSources","Mark Multiple Referenced Presets with *")
--	obs.obs_properties_add_bool(props,"markPreviewScenes","Mark Scenes containing Preview Enabled Presets with +")
--	return props
end

source_def.get_name = function()
	return "Camera Preset"
end

source_def.update = function (data, settings)
	rename_presets()
    --Sourcechanged = true
end

function cb_camera_changed(props, prop, settings)
    local ndx = (14 * (tonumber(obs.obs_data_get_string(settings, "camera")) - 1))  -- Get starting index 
	p = obs.obs_properties_get(props,"preset")
    obs.obs_property_list_clear(p)        -- clear current preset properties list
	obs.obs_property_list_add_string(p,"Home", "0")
    loadPresets()						  -- reload the presets just in case
	for i = 1, 14, 1 do
		obs.obs_property_list_add_string(p,Presets[ndx+i+5], tostring(i))  -- load the new preset properties
    end
	return true
end

source_def.get_properties = function (data)
    loadPresets()
	local props = obs.obs_properties_create()
	local prop_camera = obs.obs_properties_add_list(props, "camera", "Camera:", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	for i = 1, 5, 1 do
		if Presets[i] ~= "--Disabled--" then
			obs.obs_property_list_add_string(prop_camera,Presets[i],tostring(i))
		end 
    end

	obs.obs_property_set_modified_callback(prop_camera, cb_camera_changed)
	local prop_presets = obs.obs_properties_add_list(props, "preset", "Preset:", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(prop_presets,"Home", "0")
	for i = 1, 14, 1 do 
		obs.obs_property_list_add_string(prop_presets,Presets[i+5], tostring(i))  -- load presets for camera 1
	end 
	local prop_action = obs.obs_properties_add_list(props, "action", "Execute Preset:", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(prop_action,"On Program Only", "0")
	obs.obs_property_list_add_string(prop_action,"On Preview Only ", "1")
	obs.obs_property_list_add_string(prop_action,"On Both Preview and Program", "2")
	obs.obs_properties_add_int_slider(props,"delay","Seconds Delay Before Move",0,9,1)
	return props
end

function do_Preset(source, event)
	if not inPreset then 
		inPreset = true
		local settings = obs.obs_source_get_settings(source)
		local cam = getTempPath() .. "/SCPreset" .. obs.obs_data_get_string(settings, "camera")
		local ndx = obs.obs_data_get_string(settings, "preset")
		local dly = obs.obs_data_get_int(settings, "delay")	
		obs.obs_data_release(settings)	 
		if (event == 2) then 
			dly = "0"
		end
		local f = io.open(cam .. ".tmp", "w")              -- Create Tmp Camera preset request ile with preset and delay
		f:write(ndx .. ", " .. dly)
		f:close()
		os.rename(cam .. ".tmp", cam .. ".dat")	  -- Rename Tmp file to Camera preset command ile
		inPreset = false
	end
	return
end

source_def.create = function(settings, source)
    data = {}
	local sh = obs.obs_source_get_signal_handler(source)
	obs.signal_handler_connect(sh,"activate",active)   --Set Active Callback
	obs.signal_handler_connect(sh,"show",showing)	   --Set Preview Callback
		SourceChanged = true
	return data
end

source_def.get_defaults = function(settings) 
   obs.obs_data_set_default_string(settings, "camera", "1")
   obs.obs_data_set_default_string(settings, "preset", "1")
   obs.obs_data_set_default_string(settings, "action", "0")
   obs.obs_data_set_default_string(settings, "index", "0")
   	SourceChanged = true
end


source_def.destroy = function(source)

end


function script_description()
	return "Adds a Camera Preset"
end

function active(cd)
    local source = obs.calldata_source(cd,"source")
	local settings = obs.obs_source_get_settings(source)
    if (obs.obs_data_get_string(settings, "action") ~= '1') then 
		if not inPreset then 
   	        do_Preset(source,1)  -- Execute the camera preset with any delay
		end
    end
	obs.obs_data_release(settings)
end

function showing(cd)
    local source = obs.calldata_source(cd,"source")
	local settings = obs.obs_source_get_settings(source)
    if (obs.obs_data_get_string(settings, "action") ~= '0') then 
		if not inPreset then
   	        do_Preset(source,2)  -- Execute the camera preset with any delay
		end
    end
	obs.obs_data_release(settings)
end

loadPresets()
obs.obs_register_source(source_def);

