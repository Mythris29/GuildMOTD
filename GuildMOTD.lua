local ADDON_NAME = ... -- Pulls back the Addon-Local Variables and store them locally.

local in_world = false;
local in_combat = false;
local motd_change_pending = false;
local debug = false
local GuildMOTD_colour_name = "Guild|cFF00FF00MOTD|r"
local GuildMOTD_panel_name = GuildMOTD_colour_name

local State_StartingUp = 1
local State_SeekingData = 2
local State_Normal = 3

local state = State_StartingUp

local motd_frame = CreateFrame("Frame", "GuildMOTDFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
motd_frame:Hide()
local motd_frame_text = nil
local motd_ok_button = nil

local function build_frame()

	motd_frame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	 	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	 	tile = true,
	 	tileSize = 32,
	 	edgeSize = 32,
	 	insets = { left = 11, right = 11, top = 11, bottom = 10 }
	})

	motd_frame:SetBackdropColor(0, 0, 0, 0.9);
	motd_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	motd_frame:SetSize(440,200)
	motd_frame:SetMovable(true)

	local header_frame = CreateFrame("Frame", "GuildMOTDHeaderFrame", motd_frame, BackdropTemplateMixin and "BackdropTemplate")
	header_frame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	 	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	 	tile = true,
	 	tileSize = 28,
	 	edgeSize = 28,
	 	insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	header_frame:SetBackdropColor(0, 0, 0, 0.9);
	header_frame:SetPoint("CENTER", motd_frame, "TOP", 0, 0)

	local title_text = header_frame:CreateFontString("GuildMOTDTitleText", "ARTWORK")
	title_text:SetFontObject(GameFontNormal)
	title_text:SetText(GUILDMOTD_TITLE)
	title_text:SetJustifyH("CENTER")

	local title_string_width = title_text:GetStringWidth()
	local title_string_height = 48; --title_text:GetStringHeight()

	header_frame:SetSize(title_string_width * 1.4, title_string_height)
	title_text:SetSize(title_string_width, title_string_height)

	title_text:SetPoint("CENTER", header_frame, "CENTER", 0, 0)


	motd_frame_text = motd_frame:CreateFontString("GuildMOTDFrameText", "ARTWORK")
	motd_frame_text:SetFont("Fonts\\FRIZQT__.TTF", 16)
	motd_frame_text:SetTextColor(0, 1, 0, 0.9)
	motd_frame_text:SetPoint("CENTER", motd_frame, "CENTER", 0, 15)
	motd_frame_text:SetJustifyH("CENTER")
	motd_frame_text:SetSize(420, 100)

	motd_ok_button = CreateFrame("Button", "GuildMOTDFrameOkButton", motd_frame, "UIPanelButtonTemplate")
	motd_ok_button:SetText(OKAY)
	motd_ok_button:SetPoint("BOTTOM", motd_frame, "BOTTOM", 0, 15)
	motd_ok_button:SetScript("OnClick", function(self, button, down) motd_frame:Hide() end)
	motd_ok_button:SetSize(80, 28)

	tinsert(UISpecialFrames, motd_frame:GetName());

end

local function ShowChanged(motd)

	if (GuildMOTD_ShowOnlyChanges and (motd == GuildMOTD_LastMOTD)) then
		return false;
	end

	return true;

end

local function ShowMOTD(motd)

	GuildMOTD_LastMOTD = motd;

	if((motd == nil) or (string.len(motd) == 0)) then
		if(debug) then print("ShowMOTD given blank motd, returning") end
		return;
	end

	motd_frame_text:SetText(motd);

	local string_width = motd_frame_text:GetStringWidth()
	local string_height = motd_frame_text:GetStringHeight()



	motd_frame:Show();

end

local function OnEvent(self, event, arg1, ...)

	if(debug) then print("Event:", event, "State:", state) end

	--If the player is entering the world for the first time, everything should be loaded and ready
	if(not in_world and event == "PLAYER_ENTERING_WORLD") then

		in_world = true;

		motd_frame:UnregisterEvent("PLAYER_ENTERING_WORLD")

		motd_frame:RegisterEvent("GUILD_MOTD");
		motd_frame:RegisterEvent("GUILD_ROSTER_UPDATE");
		motd_frame:RegisterEvent("PLAYER_REGEN_DISABLED");
		motd_frame:RegisterEvent("PLAYER_REGEN_ENABLED");

		build_frame();

		local motd = GetGuildRosterMOTD();
		if((motd == nil) or (string.len(motd) == 0)) then
			state = State_SeekingData
		else
			state = State_Normal
			if (ShowChanged(motd)) then
				ShowMOTD(motd);
			end
		end

		GuildMOTDFrameOpts_CancelOrLoad();

		return;

	end

	if (event == "GUILD_MOTD") or (event == "GUILD_ROSTER_UPDATE") then

		local motd = arg1 or GetGuildRosterMOTD()

		if(debug) then print("MOTD is ", motd) end

		if((motd == nil) or (string.len(motd) == 0)) then
			if(debug) then print("MOTD is blank, returning") end
			return
		end

		-- We have a non-empty motd, business as usual from now on
		--any further changes will come via GUILD_MOTD, so we don't need GUILD_ROSTER_UPDATE
		state = State_Normal
		motd_frame:UnregisterEvent("GUILD_ROSTER_UPDATE");


		if (not in_combat) then
			if(debug) then print("not in combat") end

			if (ShowChanged(motd)) then
				ShowMOTD(motd);
			end
		else
			motd_change_pending = true;
		end

	end

	if (event == "PLAYER_REGEN_DISABLED") then
		in_combat = true;
	elseif (event == "PLAYER_REGEN_ENABLED") then
		in_combat = false;
		if (motd_change_pending) then
			motd_change_pending = false;
			ShowMOTD(GetGuildRosterMOTD());
		end
	end



end

motd_frame:SetScript("OnEvent", OnEvent)
motd_frame:SetScript("OnMouseDown", function(self) self:StartMoving(); end )
motd_frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing(); end )
motd_frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end )

motd_frame:RegisterEvent("PLAYER_ENTERING_WORLD")




SLASH_GuildMOTD1 = '/GuildMOTD';
function SlashCmdList.GuildMOTD(msg, editbox)

	if (GUILDMOTD_SHOW_CMD[msg:lower()]) then
		local motd = GetGuildRosterMOTD();
		ShowMOTD(motd);
	else
		print(GUILDMOTD_USAGE);
	end
end



function GuildMOTD_HandleEvent(self, event, ...)



	if (event == "GUILD_MOTD") or (event == "GUILD_ROSTER_UPDATE") then

		local motd = GetGuildRosterMOTD()

		if(debug) then print("MOTD is ", motd) end

		if((motd == nil) or (string.len(motd) == 0)) then
			if(debug) then print("MOTD is blank, returning") end
			return
		end

		--This GUILD_ROSTER_UPDATE made the MOTD available, so stop listening to them
		--any further changes will come via GUILD_MOTD
		if(event == "GUILD_ROSTER_UPDATE") then
			GuildMOTDFrame:UnregisterEvent("GUILD_ROSTER_UPDATE");
		end

		if (not in_combat) then
			if(debug) then print("not in combat") end

			if (ShowChanged(motd)) then
				ShowMOTD(motd);
			end
		else
			motd_change_pending = true;
		end

	end
end




--
--
--  Code for the Options frame
--
--


function GuildMOTDFrameOpts_CancelOrLoad()
	GuildMOTDFrameOpts_ShowOnlyChanges:SetChecked(GuildMOTD_ShowOnlyChanges);
end

function GuildMOTDFrameOpts_Close()
	GuildMOTD_ShowOnlyChanges = GuildMOTDFrameOpts_ShowOnlyChanges:GetChecked();
end


function GuildMOTDFrameOpts_OnLoad(panel)

	-- Set the Text for the Check boxes.
	GuildMOTDFrameOpts_ShowOnlyChangesText:SetText("Only Show Changes");

	GuildMOTDFrameOpts_Head:SetText(GuildMOTD_colour_name .. " Options (" .. C_AddOns.GetAddOnMetadata("GuildMOTD", "Version") .. ")")

	-- Set the name for the Category for the Panel
	panel.name = GuildMOTD_panel_name

	-- When the player clicks okay, set the Saved Variables to the current Check Box setting
	panel.okay = function (self) GuildMOTDFrameOpts_Close(); end;

	-- When the player clicks cancel, set the Check Box status to the Saved Variables.
	panel.cancel = function (self)  GuildMOTDFrameOpts_CancelOrLoad();  end;

	-- Add the panel to the Interface Options
	local category = Settings.RegisterCanvasLayoutCategory(panel, "GuildMOTD")
	Settings.RegisterAddOnCategory(category);
end


--
--
-- LDB Stuff
--
--
--


function GuildMOTDLDB_OnClick(clicked_frame, button)
	if button == "LeftButton" then
			local motd = GetGuildRosterMOTD();
			ShowMOTD(motd);
	elseif button == "RightButton" then
		--Call this twice otherwise it doesn't work properly. Thanks, Blizzard.
		InterfaceOptionsFrame_OpenToCategory(GuildMOTD_panel_name);
		InterfaceOptionsFrame_OpenToCategory(GuildMOTD_panel_name);
	end
end


function GuildMOTDLDB_OnTooltipShow(p_frame)

	p_frame:AddLine("Click to view the MOTD")
	p_frame:AddLine("Right-Click for options")

end

local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
if LDB then
	LDB:NewDataObject("GuildMOTD",
	 {
		type = "data source",
		text = GuildMOTD_colour_name,
		icon = "Interface\\ICONS\\INV_Misc_Food_148_CupCake",
		OnClick = GuildMOTDLDB_OnClick,
		OnTooltipShow = GuildMOTDLDB_OnTooltipShow,
	})
end
