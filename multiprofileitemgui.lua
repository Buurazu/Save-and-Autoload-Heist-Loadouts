_G.AutoloadHeistLoadouts = AutoloadHeistLoadouts or {}
AutoloadHeistLoadouts.loadout_path = SavePath .. "autoload_heist_loadouts.txt"
AutoloadHeistLoadouts.loadouts = { }

function AutoloadHeistLoadouts:Save()
	local file = io.open( self.loadout_path, "w+" )
	if file then
		file:write( json.encode( self.loadouts ) )
		file:close()
	end
end

function AutoloadHeistLoadouts:Load()
	local file = io.open( self.loadout_path, "r" )
	if file then
		self.loadouts = json.decode( file:read("*all") )
		file:close()
	end
end

AutoloadHeistLoadouts:Load()

--create the texture for save icon (if there's a better way to do this, I don't know it)
DB:create_entry(
	Idstring('texture'),
	Idstring('guis/textures/sahl/menu_save'),
	ModPath .. 'menu_save2.texture'
)

local function getDayName()	
	local stage_data = managers.job:current_stage_data()
	local level_data = managers.job:current_level_data()
	local name_id = stage_data.name_id or level_data.name_id
	local day_name = managers.localization:text(name_id)
	if (managers.skirmish:is_skirmish()) then day_name = "Holdout" end
	return day_name
end

local function loadLoadout()
	local blm = managers.blackmarket
	local loadout = AutoloadHeistLoadouts.loadouts[getDayName()]
	
	if loadout then
		managers.multi_profile:set_current_profile(loadout.profileID)
		blm:equip_weapon("primaries", loadout.primaryID)
		blm:equip_weapon("secondaries", loadout.secondaryID)
		blm:equip_melee_weapon(loadout.meleeID)
		blm:equip_grenade(loadout.throwableID)
		blm:equip_deployable({target_slot = 1, name = loadout.deployable1})
		blm:equip_deployable({target_slot = 2, name = loadout.deployable2})
		blm:equip_armor(loadout.armorID)
		managers.multi_profile:save_current()
		return true
	end
	return false
end

local function saveLoadout()
	local blm = managers.blackmarket
	local loadout = {}
	loadout.profileID = managers.multi_profile._global._current_profile
	loadout.primaryID = blm:equipped_weapon_slot("primaries")
	loadout.secondaryID = blm:equipped_weapon_slot("secondaries")
	loadout.meleeID = blm:equipped_melee_weapon()
	loadout.throwableID = blm:equipped_grenade()
	loadout.deployable1 = blm:equipped_deployable()
	loadout.deployable2 = blm:equipped_deployable(2)
	loadout.armorID = blm:equipped_armor()
	AutoloadHeistLoadouts.loadouts[getDayName()] = loadout
	AutoloadHeistLoadouts:Save()
	return true
end

local justCheckingSaveButton = false

if RequiredScript == "lib/managers/menu/multiprofileitemgui" then

	Hooks:PreHook(MultiProfileItemGui,"init","InitMultiProfile_AutoloadHeist",function(self, ws, panel)
		if not Utils:IsInGameState() then return end
		self.quick_panel_w = 72
	end)

	Hooks:PostHook(MultiProfileItemGui,"update","UpdateMultiProfile_AutoloadHeist",function(self)
		if not Utils:IsInGameState() then return end
		local save_preset = self._quick_select_panel:child("save_preset")
		if not save_preset then
			save_preset = self._quick_select_panel:bitmap({
				texture = "guis/textures/sahl/menu_save",
				name = "save_preset",
				-- make it large so that the quick switch button can't be pressed
				texture_rect = {
					0,
					0,
					40,
					40
				},
				color = tweak_data.screen_colors.button_stage_3
			})
		end
		
		save_preset:set_left(32)
		save_preset:set_center_y(self._profile_panel:h() / 2)
		
	end)

	local mouse_moved_original = MultiProfileItemGui.mouse_moved

	-- adding the Save button to the quick select panel was by far the prettiest thing visually,
	-- but a nightmare to prevent the normal quick select button being counted as highlighted
	function MultiProfileItemGui:mouse_moved(x, y, ...)
		if not Utils:IsInGameState() then return mouse_moved_original(self, x, y, ...) end
		local used, pointer = mouse_moved_original(self, x, y, ...)
		
		local save_preset = self._quick_select_panel:child("save_preset")
		if save_preset then
			if save_preset:inside(x, y) then
				if self._is_save_selected ~= true then
					save_preset:set_color(tweak_data.screen_colors.button_stage_2)
					managers.menu_component:post_event("highlight")

					self._is_save_selected = true
				end

				self._arrow_selection = "save_mod"
				pointer = "link"
				used = true
				if self._is_quick_selected == true then
					for _, element in ipairs(self._quick_select_panel_elements) do
						element:set_color(tweak_data.screen_colors.button_stage_3)
					end
				end
			elseif self._is_save_selected == true then
				save_preset:set_color(tweak_data.screen_colors.button_stage_3)
				if self._is_quick_selected == true then
					managers.menu_component:post_event("highlight")
					for _, element in ipairs(self._quick_select_panel_elements) do
						element:set_color(tweak_data.screen_colors.button_stage_2)
					end
				end
				
				self._is_save_selected = false
			end
		end
		
		return used, pointer
	end

	function MultiProfileItemGui:CheckSaveButtonClick(button, x, y)
		if not Utils:IsInGameState() then return end
		if button == Idstring("0") then
			if self:arrow_selection() == "save_mod" then
				
				if (saveLoadout()) then
					managers.chat:_receive_message(1,"Heist Loadouts","Loadout for " .. getDayName() .. " saved",Color("CC4040"))
				end
				managers.menu_component:post_event("menu_enter")

				return
			end
		end
	end

elseif RequiredScript == "lib/managers/menu/missionbriefinggui" then
	local firstTime = true
	
	Hooks:PreHook(MissionBriefingGui,"init","MissionBriefingInit_AutoloadHeist",function(self, ...)
		if firstTime then
			firstTime = fals
			if loadLoadout() then
				DelayedCalls:Add( "SAHLMessage", 1, function()
					managers.chat:_receive_message(1,"Heist Loadouts","Loadout for " .. getDayName() .. " loaded",Color("CC4040"))
				end )
			end
		end
	end)
	
	Hooks:PostHook(MissionBriefingGui,"mouse_pressed","MissionBriefingMousePressed_AutoloadHeist",function(self, button, x, y)
		-- manually check for our save button being pressed, because the multi profile thing doesn't get checked if we're Ready
		self._multi_profile_item:CheckSaveButtonClick(button, x, y)
	end)
	
end