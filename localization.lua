

local function Set (list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

-- Set defaults
GUILDMOTD_TITLE = GUILD_MOTD;
GUILDMOTD_USAGE = "Usage: /GuildMOTD show|mostra";
GUILDMOTD_SHOW_CMD = Set{"show", "mostra" };
