local ADDON_NAME = ... -- Pulls back the Addon-Local Variables and store them locally.

local in_world = false;
local in_combat = false;
local motd_change_pending = false;
local debug = false
local GuildMOTD_colour_name = "Guild |cFF00FF00MOTD|r Popup"
local GuildMOTD_ldb_name = "Guild|cFF00FF00MOTD|r"

local State_StartingUp = 1
local State_SeekingData = 2
local State_Normal = 3

local state = State_StartingUp

local motd_frame = CreateFrame("Frame", "GuildMOTDFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
motd_frame:Hide()
local motd_frame_text = nil
local motd_ok_button = nil
local options_category = nil
local header_frame = nil
local guild_name_text = nil
local guild_emblem_left = nil
local guild_emblem_left_bg = nil
local guild_emblem_left_border = nil
local guild_emblem_right = nil
local guild_emblem_right_bg = nil
local guild_emblem_right_border = nil

local function UpdateGuildInfo()
	if not guild_name_text then
		return
	end

	local guildName = GetGuildInfo("player")

	if guildName and IsInGuild() then
		guild_name_text:SetText(guildName)
		guild_name_text:Show()
		SetSmallGuildTabardTextures("player", guild_emblem_left, guild_emblem_left_bg, guild_emblem_left_border)
		SetSmallGuildTabardTextures("player", guild_emblem_right, guild_emblem_right_bg, guild_emblem_right_border)
		guild_emblem_left:Show(); guild_emblem_left_bg:Show(); guild_emblem_left_border:Show()
		guild_emblem_right:Show(); guild_emblem_right_bg:Show(); guild_emblem_right_border:Show()
	else
		guild_name_text:SetText("")
		guild_name_text:Hide()
		guild_emblem_left:Hide(); guild_emblem_left_bg:Hide(); guild_emblem_left_border:Hide()
		guild_emblem_right:Hide(); guild_emblem_right_bg:Hide(); guild_emblem_right_border:Hide()
	end
end

local function EnsureSettingsTables()
	if GuildMOTD_Global == nil then
		-- Migrate from legacy flat per-character vars if present (one-time, on upgrade).
		GuildMOTD_Global = {
			ShowOnlyChanges = (GuildMOTD_ShowOnlyChanges ~= nil) and GuildMOTD_ShowOnlyChanges or false,
			ShowOncePerSession = (GuildMOTD_ShowOncePerSession == nil) and true or GuildMOTD_ShowOncePerSession,
			Opacity = GuildMOTD_Opacity or 0.9,
		}
		-- Clear the legacy vars so they don't linger.
		GuildMOTD_ShowOnlyChanges = nil
		GuildMOTD_ShowOncePerSession = nil
		GuildMOTD_Opacity = nil
	end
	if GuildMOTD_Char == nil then
		GuildMOTD_Char = {
			UseCharacterSettings = false,
			ShowOnlyChanges = GuildMOTD_Global.ShowOnlyChanges,
			ShowOncePerSession = GuildMOTD_Global.ShowOncePerSession,
			Opacity = GuildMOTD_Global.Opacity,
		}
	end
end

local function GetSetting(key)
	EnsureSettingsTables()
	if GuildMOTD_Char.UseCharacterSettings then
		return GuildMOTD_Char[key]
	end
	return GuildMOTD_Global[key]
end

local function SetSetting(key, value)
	EnsureSettingsTables()
	if GuildMOTD_Char.UseCharacterSettings then
		GuildMOTD_Char[key] = value
	else
		GuildMOTD_Global[key] = value
	end
end

local function SetUseCharacterSettings(enabled)
	EnsureSettingsTables()
	if enabled and not GuildMOTD_Char.UseCharacterSettings then
		-- Copy current global values into char table so behavior is seamless at toggle time.
		GuildMOTD_Char.ShowOnlyChanges = GuildMOTD_Global.ShowOnlyChanges
		GuildMOTD_Char.ShowOncePerSession = GuildMOTD_Global.ShowOncePerSession
		GuildMOTD_Char.Opacity = GuildMOTD_Global.Opacity
	end
	GuildMOTD_Char.UseCharacterSettings = enabled
end

local function ApplyOpacity(alpha)
	alpha = alpha or 0.9;
	if motd_frame then
		motd_frame:SetBackdropColor(0, 0, 0, alpha);
	end
	if header_frame then
		header_frame:SetBackdropColor(0, 0, 0, alpha);
	end
end

local function ApplyWindowPosition()
	if not motd_frame then return end
	motd_frame:ClearAllPoints();
	if GuildMOTD_Global and GuildMOTD_Global.WindowPoint then
		motd_frame:SetPoint(
			GuildMOTD_Global.WindowPoint,
			UIParent,
			GuildMOTD_Global.WindowRelPoint or GuildMOTD_Global.WindowPoint,
			GuildMOTD_Global.WindowX or 0,
			GuildMOTD_Global.WindowY or 0
		);
	else
		motd_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	end
end

local function SaveWindowPosition()
	if not motd_frame then return end
	EnsureSettingsTables();
	local point, _, relativePoint, x, y = motd_frame:GetPoint(1);
	GuildMOTD_Global.WindowPoint = point;
	GuildMOTD_Global.WindowRelPoint = relativePoint;
	GuildMOTD_Global.WindowX = x;
	GuildMOTD_Global.WindowY = y;
end

function GuildMOTDFrameOpts_ResetPosition()
	EnsureSettingsTables();
	GuildMOTD_Global.WindowPoint = nil;
	GuildMOTD_Global.WindowRelPoint = nil;
	GuildMOTD_Global.WindowX = nil;
	GuildMOTD_Global.WindowY = nil;
	ApplyWindowPosition();
end

local function build_frame()

	motd_frame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	 	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	 	tile = true,
	 	tileSize = 32,
	 	edgeSize = 32,
	 	insets = { left = 11, right = 11, top = 11, bottom = 10 }
	})

	motd_frame:SetBackdropColor(0, 0, 0, GetSetting("Opacity"));
	ApplyWindowPosition()
	motd_frame:SetSize(480, 240)
	motd_frame:SetMovable(true)

	header_frame = CreateFrame("Frame", "GuildMOTDHeaderFrame", motd_frame, BackdropTemplateMixin and "BackdropTemplate")
	header_frame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	 	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	 	tile = true,
	 	tileSize = 28,
	 	edgeSize = 28,
	 	insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	header_frame:SetBackdropColor(0, 0, 0, GetSetting("Opacity"));
	-- Header just above main box, almost touching.
	header_frame:SetPoint("BOTTOM", motd_frame, "TOP", 0, -8)

	local title_text = header_frame:CreateFontString("GuildMOTDTitleText", "ARTWORK")
	title_text:SetFontObject(GameFontNormal)
	title_text:SetText(GUILDMOTD_TITLE)
	title_text:SetJustifyH("CENTER")

	local title_string_width = title_text:GetStringWidth()
	local title_string_height = 40;

	header_frame:SetSize(title_string_width * 1.4, title_string_height)
	title_text:SetSize(title_string_width, title_string_height)

	title_text:SetPoint("CENTER", header_frame, "CENTER", 0, 0)

	-- Guild name row: guild name centered near top, flanked by tabard emblems.
	guild_name_text = motd_frame:CreateFontString("GuildMOTDGuildNameText", "ARTWORK")
	guild_name_text:SetFontObject(GameFontNormalLarge)
	guild_name_text:SetJustifyH("CENTER")
	guild_name_text:SetPoint("TOP", motd_frame, "TOP", 0, -24)
	guild_name_text:SetSize(320, 28)

	local emblem_size = 36

	guild_emblem_left_bg = motd_frame:CreateTexture(nil, "BACKGROUND")
	guild_emblem_left_bg:SetSize(emblem_size, emblem_size)
	guild_emblem_left_bg:SetPoint("RIGHT", guild_name_text, "LEFT", -6, 0)

	guild_emblem_left = motd_frame:CreateTexture(nil, "ARTWORK")
	guild_emblem_left:SetSize(emblem_size, emblem_size)
	guild_emblem_left:SetPoint("CENTER", guild_emblem_left_bg, "CENTER")

	guild_emblem_left_border = motd_frame:CreateTexture(nil, "OVERLAY")
	guild_emblem_left_border:SetSize(emblem_size, emblem_size)
	guild_emblem_left_border:SetPoint("CENTER", guild_emblem_left_bg, "CENTER")

	guild_emblem_right_bg = motd_frame:CreateTexture(nil, "BACKGROUND")
	guild_emblem_right_bg:SetSize(emblem_size, emblem_size)
	guild_emblem_right_bg:SetPoint("LEFT", guild_name_text, "RIGHT", 6, 0)

	guild_emblem_right = motd_frame:CreateTexture(nil, "ARTWORK")
	guild_emblem_right:SetSize(emblem_size, emblem_size)
	guild_emblem_right:SetPoint("CENTER", guild_emblem_right_bg, "CENTER")

	guild_emblem_right_border = motd_frame:CreateTexture(nil, "OVERLAY")
	guild_emblem_right_border:SetSize(emblem_size, emblem_size)
	guild_emblem_right_border:SetPoint("CENTER", guild_emblem_right_bg, "CENTER")

	-- MOTD text: moved down below the guild name row, with wider left/right margins.
	motd_frame_text = motd_frame:CreateFontString("GuildMOTDFrameText", "ARTWORK")
	motd_frame_text:SetFont("Fonts\\FRIZQT__.TTF", 16)
	motd_frame_text:SetTextColor(0, 1, 0, 0.9)
	motd_frame_text:SetPoint("TOP", motd_frame, "TOP", 0, -70)
	motd_frame_text:SetJustifyH("CENTER")
	motd_frame_text:SetSize(400, 110)

	motd_ok_button = CreateFrame("Button", "GuildMOTDFrameOkButton", motd_frame, "UIPanelButtonTemplate")
	motd_ok_button:SetText(OKAY)
	motd_ok_button:SetPoint("BOTTOM", motd_frame, "BOTTOM", 0, 15)
	motd_ok_button:SetScript("OnClick", function(self, button, down) motd_frame:Hide() end)
	motd_ok_button:SetSize(80, 28)

	tinsert(UISpecialFrames, motd_frame:GetName());

	-- Initial guild info pass; guild data may not be ready yet on first login.
	-- Schedule delayed retries to catch the race where guild data arrives after PLAYER_ENTERING_WORLD.
	UpdateGuildInfo();
	C_Timer.After(2, UpdateGuildInfo);
	C_Timer.After(5, UpdateGuildInfo);

end

local function ShowChanged(motd)

	if (GetSetting("ShowOnlyChanges") and (motd == GuildMOTD_LastMOTD)) then
		return false;
	end

	return true;

end

local function IsNewMOTD(motd)
	return motd ~= GuildMOTD_LastMOTD;
end

local function ShowMOTD(motd)

	GuildMOTD_LastMOTD = motd;

	if((motd == nil) or (string.len(motd) == 0)) then
		if(debug) then print("ShowMOTD given blank motd, returning") end
		return;
	end

	motd_frame_text:SetText(motd);

	motd_frame:Show();

	GuildMOTD_MOTDShownThisSession = true;

end

local function ShouldShow(motd)

	-- Always show a newly changed MOTD (bypasses ShowOncePerSession for real updates)
	if (IsNewMOTD(motd)) then
		return true;
	end

	-- Same MOTD as last-shown. Apply filters.
	if (not ShowChanged(motd)) then
		return false;
	end

	if (GetSetting("ShowOncePerSession") and GuildMOTD_MOTDShownThisSession) then
		return false;
	end

	return true;

end

local function OnEvent(self, event, arg1, ...)

	if(debug) then print("Event:", event, "State:", state) end

	--If the player is entering the world for the first time, everything should be loaded and ready
	if(not in_world and event == "PLAYER_ENTERING_WORLD") then

		in_world = true;

		local isInitialLogin = arg1;
		if (isInitialLogin) then
			GuildMOTD_MOTDShownThisSession = false;
		end

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
			if (ShouldShow(motd)) then
				ShowMOTD(motd);
			end
		end

		GuildMOTDFrameOpts_CancelOrLoad();

		return;

	end

	if (event == "GUILD_MOTD") or (event == "GUILD_ROSTER_UPDATE") then

		UpdateGuildInfo();

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

			if (ShouldShow(motd)) then
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
motd_frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing(); SaveWindowPosition(); end )

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







--
--
--  Code for the Options frame
--
--


function GuildMOTDFrameOpts_CancelOrLoad()
	EnsureSettingsTables();
	GuildMOTDFrameOpts_UseCharacterSettings:SetChecked(GuildMOTD_Char.UseCharacterSettings);
	GuildMOTDFrameOpts_ShowOnlyChanges:SetChecked(GetSetting("ShowOnlyChanges"));
	GuildMOTDFrameOpts_ShowOncePerSession:SetChecked(GetSetting("ShowOncePerSession"));
	GuildMOTDFrameOpts_OpacitySlider:SetValue(GetSetting("Opacity"));
end

function GuildMOTDFrameOpts_Close()
	SetSetting("ShowOnlyChanges", GuildMOTDFrameOpts_ShowOnlyChanges:GetChecked());
	SetSetting("ShowOncePerSession", GuildMOTDFrameOpts_ShowOncePerSession:GetChecked());
	SetSetting("Opacity", GuildMOTDFrameOpts_OpacitySlider:GetValue());
end


function GuildMOTDFrameOpts_UseCharacterSettings_OnClick()
	local enabled = GuildMOTDFrameOpts_UseCharacterSettings:GetChecked();
	SetUseCharacterSettings(enabled);
	-- Refresh the other widgets to reflect the now-active scope.
	GuildMOTDFrameOpts_CancelOrLoad();
	ApplyOpacity(GetSetting("Opacity"));
end

function GuildMOTDFrameOpts_OnLoad(panel)

	-- Set the Text for the Check boxes.
	GuildMOTDFrameOpts_UseCharacterSettingsText:SetText("Use Character-Specific Settings");
	GuildMOTDFrameOpts_ShowOnlyChangesText:SetText("Only Show Changes");
	GuildMOTDFrameOpts_ShowOncePerSessionText:SetText("Only Show Once Per Session");

	-- Save state immediately when checkboxes are toggled.
	-- (The new Settings API doesn't reliably call panel.okay, so we persist on each click.)
	GuildMOTDFrameOpts_UseCharacterSettings:HookScript("OnClick", GuildMOTDFrameOpts_UseCharacterSettings_OnClick);
	GuildMOTDFrameOpts_ShowOnlyChanges:HookScript("OnClick", GuildMOTDFrameOpts_Close);
	GuildMOTDFrameOpts_ShowOncePerSession:HookScript("OnClick", GuildMOTDFrameOpts_Close);

	-- Configure the opacity slider.
	GuildMOTDFrameOpts_OpacitySlider:SetMinMaxValues(0.1, 1.0);
	GuildMOTDFrameOpts_OpacitySlider:SetValueStep(0.05);
	GuildMOTDFrameOpts_OpacitySlider:SetObeyStepOnDrag(true);
	GuildMOTDFrameOpts_OpacitySliderLow:SetText("10%");
	GuildMOTDFrameOpts_OpacitySliderHigh:SetText("100%");
	GuildMOTDFrameOpts_OpacitySliderText:SetText("Window Opacity");
	GuildMOTDFrameOpts_OpacitySlider:HookScript("OnValueChanged", function(self, value)
		SetSetting("Opacity", value);
		ApplyOpacity(value);
	end);

	GuildMOTDFrameOpts_Head:SetText(GuildMOTD_colour_name .. " Options (" .. C_AddOns.GetAddOnMetadata("GuildMOTD", "Version") .. ")")

	-- Add the panel to the Interface Options
	options_category = Settings.RegisterCanvasLayoutCategory(panel, "GuildMOTD")
	Settings.RegisterAddOnCategory(options_category);
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
		if options_category then
			Settings.OpenToCategory(options_category.ID)
		end
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
		text = GuildMOTD_ldb_name,
		icon = "Interface\\AddOns\\GuildMOTD\\Textures\\icon.tga",
		OnClick = GuildMOTDLDB_OnClick,
		OnTooltipShow = GuildMOTDLDB_OnTooltipShow,
	})
end
