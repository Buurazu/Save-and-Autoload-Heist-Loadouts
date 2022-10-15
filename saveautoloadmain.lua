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

-- We can't just grab the job name and append "2" or "3" to it because that breaks in Crime Spree
-- So this table converts the Day Names into Job Name + Day Number
-- It also handles merging Bank Heists and Transports, and Election Day Plan C
local predefined = {
	["Bank Heist: Deposit"] = "Bank Heist",
	["Bank Heist: Cash"] = "Bank Heist",
	["Bank Heist: Gold"] = "Bank Heist",
	["Bank Heist: Random"] = "Bank Heist",
	["Transport: Crossroads"] = "Transports",
	["Transport: Downtown"] = "Transports",
	["Transport: Harbor"] = "Transports",
	["Transport: Park"] = "Transports",
	["Transport: Underpass"] = "Transports",
	["Garnet Group Boutique"] = "Reservoir Dogs Heist 2",
	["Safe house Nightmare"] = "Safe House Nightmare",
	
	["Code for Meth"] = "Rats 2",
	["Bus Stop"] = "Rats 3",
	["FBI Server"] = "Firestarter 2",
	["Trustee Bank"] = "Bank Heist", --Firestarter 3
	["Boat Load"] = "Watchdogs 2",
	
	["Four Floors"] = "Hotline Miami 2",
	["The Search"] = "Hoxton Breakout 2",
	
	["Train Trade"] = "Framing Frame 2",
	["Framing"] = "Framing Frame 3",
	["Swing Vote"] = "Election Day 2",
	["Breaking Ballot"] = "Election Day Plan C",
	["Engine Problem"] = "Big Oil 2",
	["Interception"] = "The Biker Heist 2",
	["Dirty work"] = "Goat Simulator 2",
}

local function getDayName()
	local job_name = managers.localization:text(tweak_data.narrative.jobs[managers.job:current_real_job_id()].name_id)
	local job_day = managers.job:current_stage()
	if (job_day > 1) then job_name = job_name .. " " .. job_day end
	
	--this should work well for all Day 1 Crime Spree missions
	if (managers.crime_spree:is_active()) then
		job_name = managers.localization:text(managers.crime_spree:get_narrative_tweak_data_for_mission_level(managers.crime_spree:current_mission()).name_id)
	end
	
	local stage_data = managers.job:current_stage_data()
	local level_data = managers.job:current_level_data()
	local name_id = stage_data.name_id or level_data.name_id
	local day_name = managers.localization:text(name_id)
	
	if (predefined[day_name]) then job_name = predefined[day_name] end -- Day Name -> Job Name #
	if (predefined[job_name]) then job_name = predefined[job_name] end -- consolidate Bank Heists into one thing
	if (managers.skirmish:is_skirmish()) then job_name = "Holdout" end
	return job_name
end

local function loadLoadout()
	local blm = managers.blackmarket
	local loadout = AutoloadHeistLoadouts.loadouts[getDayName()]
	
	local loadedString = ""
	
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
		
		loadedString = loadedString .. managers.multi_profile:current_profile_name() .. " Profile"
		-- don't use the loadout's saved IDs here, in case the equip failed
		-- this way, if our weapons are different due to level requirement or such, the player knows
		loadedString = loadedString .. ", " .. (blm:get_crafted_custom_name("primaries", blm:equipped_weapon_slot("primaries")) or blm:get_weapon_name_by_category_slot("primaries", blm:equipped_weapon_slot("primaries")) or "Unknown Primary")
		loadedString = loadedString .. ", " .. (blm:get_crafted_custom_name("secondaries", blm:equipped_weapon_slot("secondaries")) or blm:get_weapon_name_by_category_slot("secondaries", blm:equipped_weapon_slot("secondaries")) or "Unknown Secondary")
		return loadedString
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

if RequiredScript == "lib/managers/menu/missionbriefinggui" then
	local firstTime = true -- init is called each time you switch profiles
	
	Hooks:PreHook(MissionBriefingGui,"init","MissionBriefingInit_AutoloadHeist",function(self, ...)
		if firstTime then
			firstTime = false
			loadoutString = loadLoadout()
			if loadoutString then
				-- delay it because chat isn't ready yet
				DelayedCalls:Add( "SAHLMessage", 1, function()
					managers.chat:_receive_message(1,"Heist Loadouts","Loadout for " .. getDayName() .. " loaded: " .. loadoutString,Color("CC4040"))
				end )
			end
		end
	end)
	Hooks:PostHook(MissionBriefingGui,"init","MissionBriefingPostInit_AutoloadHeist",function(self, ...)
		self._save_preset_mod = self._panel:bitmap({
			texture = "guis/textures/sahl/menu_save",
			name = "save_preset",
			texture_rect = {
				4,
				2,
				38,
				38
			},
			color = tweak_data.screen_colors.button_stage_3,
			layer = 2
		})
		self._save_preset_mod:set_right(self._multi_profile_item:panel():w() + 40)
		self._save_preset_mod:set_bottom(self._panel:h()+2)
	end)
	
	-- can't just hook this if we want to change the pointer icon properly
	local mouse_moved_original = MissionBriefingGui.mouse_moved
	function MissionBriefingGui:mouse_moved(x, y, ...)
		local used, pointer = mouse_moved_original(self, x, y, ...)
		
		if self._save_preset_mod:inside(x, y) then
			if self._is_save_selected ~= true then
				self._save_preset_mod:set_color(tweak_data.screen_colors.button_stage_2)
				managers.menu_component:post_event("highlight")

				self._is_save_selected = true
			end

			pointer = "link"
			used = true
		elseif self._is_save_selected == true then
			self._save_preset_mod:set_color(tweak_data.screen_colors.button_stage_3)
			
			self._is_save_selected = false
		end
		return used, pointer
	end
	
	Hooks:PostHook(MissionBriefingGui,"mouse_pressed","MissionBriefingMousePressed_AutoloadHeist",function(self, button, x, y)
		if button == Idstring("0") then
			if self._is_save_selected then
				
				if (saveLoadout()) then
					managers.chat:_receive_message(1,"Heist Loadouts","Loadout for " .. getDayName() .. " saved",Color("CC4040"))
				end
				managers.menu_component:post_event("menu_enter")

				return
			end
		end
	end)
	
end