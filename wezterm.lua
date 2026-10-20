-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- ─── Tab management state ──────────────────────────────────────────────────
local tab_names   = {}  -- [tab_id]    = custom name string
local last_tab    = {}  -- [window_id] = previously active tab_id
local current_tab = {}  -- [window_id] = currently active tab_id (change detection)

-- ─── Process helpers ───────────────────────────────────────────────────────
local SHELL_PROCS = {
	bash=true, zsh=true, fish=true, sh=true,
	cmd=true, pwsh=true, nu=true, shell=true,
}

-- Per-process accent colors: { active_bg, active_fg, inactive_fg }
local PROC_COLORS = {
	nvim    = { "#9d79d6", "#192330", "#9d79d6" },
	vim     = { "#9d79d6", "#192330", "#9d79d6" },
	lazygit = { "#dbc074", "#192330", "#a89050" },
	git     = { "#dbc074", "#192330", "#a89050" },
	node    = { "#81b29a", "#192330", "#81b29a" },
	python  = { "#81b29a", "#192330", "#81b29a" },
	python3 = { "#81b29a", "#192330", "#81b29a" },
	deno    = { "#81b29a", "#192330", "#81b29a" },
	default = { "#719cd6", "#192330", "#738091" },
}

local function get_proc(raw)
	local p = (raw or ""):match("([^/\\]+)$") or "shell"
	return p:gsub("%.exe$", "")
end

-- resolve_proc(raw_proc, title) → color_key, display
--
-- Primary source: the pane title set by the application itself.
-- nvim is configured to set its title to "nvim: <filename>", which is
-- unambiguous — LSP servers (node, ruff, pyright…) never set terminal titles.
-- Process name is only used as a last resort for non-nvim processes.
local TITLE_HINTS = {
	{ pattern = "^nvim:%s*(.+)",  key = "nvim"    },  -- nvim: filename  (primary)
	{ pattern = "lazygit",        key = "lazygit" },
	{ pattern = "[Hh][Tt][Oo][Pp]", key = "htop"  },
	{ pattern = "[Bb][Tt][Oo][Pp]", key = "btop"  },
}

local function resolve_proc(raw_proc, title)
	local t = title or ""
	-- nvim title: "nvim: filename.ext"  →  color=nvim, display=filename.ext
	local filename = t:match("^nvim:%s*(.+)$")
	if filename and filename ~= "" and filename ~= "[No Name]" then
		return "nvim", filename
	end
	-- Other title hints (lazygit, htop, btop)
	for _, hint in ipairs(TITLE_HINTS) do
		if t:find(hint.pattern) then
			return hint.key, hint.key
		end
	end
	-- Fall back to process name for shells and anything else
	local proc = get_proc(raw_proc)
	return proc, proc
end

-- Build a tab label; uses `:*` separator when a non-shell process is running.
-- color_key drives the color lookup; display is what's shown in the label.
local function tab_label(idx, color_key, display, custom_name)
	local text = custom_name or display
	local sep  = SHELL_PROCS[color_key] and ": " or ":*"
	return string.format("  %d%s%s  ", idx, sep, text)
end

-- Default program: hoot's desk (hoot's frame and sidebar round your shell)
-- when hoot is installed, else the plain shell. Matches Windows Terminal's
-- default profile, so $PROFILE loads the same way here as there.
local is_windows = wezterm.target_triple:find("windows") ~= nil
local function exists(path)
	local f = io.open(path, "r")
	if f then f:close() end
	return f ~= nil
end
local hoot_paths = is_windows and { "D:/code/hoot/hoot.exe" }
	or { (os.getenv("HOME") or "") .. "/go/bin/hoot", "/opt/homebrew/bin/hoot", "/usr/local/bin/hoot" }
for _, p in ipairs(hoot_paths) do
	if exists(p) then
		config.default_prog = { p, "-desk" }
		break
	end
end
if not config.default_prog and is_windows then
	config.default_prog = { "powershell.exe" }
end

-- Font settings
config.font = wezterm.font("BlexMono Nerd Font", { weight = "Regular" })
config.font_rules = {
  { italic = true,  intensity = "Normal", font = wezterm.font("BlexMono Nerd Font", { weight = "Regular", italic = true }) },
  { italic = true,  intensity = "Bold",   font = wezterm.font("BlexMono Nerd Font", { weight = "Bold",    italic = true }) },
  { italic = false, intensity = "Bold",   font = wezterm.font("BlexMono Nerd Font", { weight = "Bold" }) },
}
config.font_size = 10
config.line_height = 1.1
config.cell_width = 1.0

-- Font rendering optimizations
config.freetype_load_target = "Normal"
config.freetype_render_target = "Normal"
config.freetype_load_flags = "NO_HINTING"

-- Window settings
config.window_background_opacity = 0.95
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

-- Tab bar settings
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_tab_index_in_tab_bar = true

-- Performance settings
config.max_fps = 60
config.animation_fps = 60
config.cursor_blink_rate = 500

-- Disable updates
config.show_update_window = false
config.check_for_updates = false

-- Session management
config.default_workspace = "main"

-- Nightfox colorscheme with updated tab bar colors
config.colors = {
	-- Base colors
	foreground = "#c0caf5",
	background = "#192330",
	cursor_bg = "#c0caf5",
	cursor_fg = "#192330",
	cursor_border = "#c0caf5",
	selection_fg = "#c0caf5",
	selection_bg = "#2d3f76",
	scrollbar_thumb = "#29394f",
	split = "#29394f",

	-- ANSI colors
	ansi = {
		"#393b44", -- black
		"#c94f6d", -- red
		"#81b29a", -- green
		"#dbc074", -- yellow
		"#719cd6", -- blue
		"#9d79d6", -- magenta
		"#63cdcf", -- cyan
		"#dfdfe0", -- white
	},
	brights = {
		"#575860", -- bright black
		"#d16983", -- bright red
		"#8ebaa4", -- bright green
		"#e0c989", -- bright yellow
		"#86abdc", -- bright blue
		"#baa1e2", -- bright magenta
		"#7ad4d6", -- bright cyan
		"#e4e4e5", -- bright white
	},

	tab_bar = {
		background = "#131a24",
		active_tab = {
			bg_color = "#719cd6",
			fg_color = "#192330",
			intensity = "Bold",
			underline = "None",
			italic = false,
			strikethrough = false,
		},
		inactive_tab = {
			bg_color = "#131a24",
			fg_color = "#738091",
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},
		inactive_tab_hover = {
			bg_color = "#29394f",
			fg_color = "#c0caf5",
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},
		new_tab = {
			bg_color = "#131a24",
			fg_color = "#738091",
		},
		new_tab_hover = {
			bg_color = "#29394f",
			fg_color = "#c0caf5",
		},
	},
}

-- ─── Tab rendering ─────────────────────────────────────────────────────────
-- Renders each tab with process-specific accent colors.
-- Busy tabs (non-shell foreground process) show a :* separator.
-- Custom names set via Ctrl+Shift+R are shown instead of the process name.
wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
	local color_key, display = resolve_proc(tab.active_pane.foreground_process_name, tab.active_pane.title)
	local label  = tab_label(tab.tab_index + 1, color_key, display, tab_names[tab.tab_id])
	local colors = PROC_COLORS[color_key] or PROC_COLORS.default

	if tab.is_active then
		return {
			{ Background = { Color = colors[1] } },
			{ Foreground = { Color = colors[2] } },
			{ Attribute = { Intensity = "Bold" } },
			{ Text = label },
		}
	else
		return {
			{ Background = { Color = "#131a24" } },
			{ Foreground = { Color = colors[3] } },
			{ Attribute = { Intensity = "Normal" } },
			{ Text = label },
		}
	end
end)

-- ─── Status bar ────────────────────────────────────────────────────────────
-- Left status = centering padding only (tabs rendered natively after it).
-- Right status = dir [workspace Nt] HH:MM
-- Also tracks the previously active tab for the last-tab toggle (Alt+\).
wezterm.on("update-status", function(window, pane)
	-- Track last-used tab
	local win_id    = window:window_id()
	local active_id = window:active_tab():tab_id()
	if current_tab[win_id] and current_tab[win_id] ~= active_id then
		last_tab[win_id] = current_tab[win_id]
	end
	current_tab[win_id] = active_id

	-- Centering: sum label widths (must match tab_label output)
	local all_tabs  = window:tabs()
	local total_len = 0
	for i, t in ipairs(all_tabs) do
		local ap                  = t:active_pane()
		local color_key, display  = resolve_proc(ap:get_foreground_process_name(), ap:get_title())
		total_len                 = total_len + #tab_label(i, color_key, display, tab_names[t:tab_id()])
	end

	local cols = pane:get_dimensions().cols
	local pad  = math.max(0, math.floor((cols - total_len) / 2))

	window:set_left_status(wezterm.format({
		{ Background = { Color = "#131a24" } },
		{ Text = string.rep(" ", pad) },
	}))

	-- Right status
	local date    = wezterm.strftime("%H:%M")
	local cwd     = pane:get_current_working_dir()
	local dir_name = ""
	if cwd and cwd.file_path then
		dir_name = cwd.file_path:match("([^/\\]+)[/\\]?$") or ""
		if #dir_name > 12 then dir_name = dir_name:sub(1, 9) .. "..." end
	end
	local workspace = window:active_workspace() or "default"
	local ntabs     = #all_tabs
	local status    = (dir_name ~= "" and (dir_name .. " ") or "")
		.. "[" .. workspace .. " " .. ntabs .. "t] "
		.. date
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = "#738091" } },
		{ Text = " " .. status .. " " },
	}))
end)

-- ─── Session persistence ───────────────────────────────────────────────────
wezterm.on("save-session", function(window, pane)
	local workspace = window:active_workspace()
	local state_file = wezterm.home_dir .. "/.wezterm_session_" .. workspace .. ".txt"

	local tabs = {}
	for _, tab in ipairs(window:tabs()) do
		local tab_cwd = tab:active_pane():get_current_working_dir()
		local process = tab:active_pane():get_foreground_process_name()
		if tab_cwd then
			table.insert(tabs, {
				cwd = tab_cwd.file_path or wezterm.home_dir,
				process = process or "shell"
			})
		else
			table.insert(tabs, {
				cwd = wezterm.home_dir,
				process = "shell"
			})
		end
	end

	local file = io.open(state_file, "w")
	if file then
		file:write(wezterm.json_encode(tabs))
		file:close()
		wezterm.log_info("Session saved: " .. #tabs .. " tabs for workspace: " .. workspace)
	end
end)

wezterm.on("window-will-close", function(window, pane)
	wezterm.emit("save-session", window, pane)
end)

wezterm.on("restore-session", function(window, pane)
	local workspace = window:active_workspace()
	local state_file = wezterm.home_dir .. "/.wezterm_session_" .. workspace .. ".txt"

	local file = io.open(state_file, "r")
	if file then
		local content = file:read("*all")
		file:close()

		local success, tabs = pcall(wezterm.json_decode, content)
		if success and tabs and #tabs > 0 then
			for i, tab_info in ipairs(tabs) do
				if i == 1 then
					pane:send_text("cd " .. wezterm.shell_quote_arg(tab_info.cwd) .. "\r")
				else
					window:perform_action(wezterm.action.SpawnTab {
						CurrentPaneDomain = { cwd = tab_info.cwd }
					}, pane)
				end
			end
			wezterm.log_info("Session restored: " .. #tabs .. " tabs for workspace: " .. workspace)
			return true
		end
	end
	return false
end)

-- ─── Key bindings ──────────────────────────────────────────────────────────
config.keys = {
	-- Font size
	{ key = "=", mods = "CTRL",     action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CTRL",     action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CTRL",     action = wezterm.action.ResetFontSize },

	-- Copy/Paste
	{ key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
	{ key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },

	-- Tabs: open / close (smart: prompts only for nvim/lazygit)
	{ key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(window, pane)
		local proc = get_proc(pane:get_foreground_process_name())
		if proc == "nvim" or proc == "vim" then
			-- Let nvim close itself — :confirm qa prompts for unsaved buffers
			-- via noice rather than force-killing and getting E162 errors
			pane:send_text(":confirm qa\r")
		elseif proc == "lazygit" then
			window:perform_action(wezterm.action.CloseCurrentTab({ confirm = true }), pane)
		else
			window:perform_action(wezterm.action.CloseCurrentTab({ confirm = false }), pane)
		end
	end) },

	-- Rename current tab (empty input clears the custom name)
	{ key = "r", mods = "CTRL|SHIFT", action = wezterm.action.PromptInputLine({
		description = "Rename tab (empty to clear)",
		action = wezterm.action_callback(function(window, pane, line)
			if line ~= nil then
				local id = window:active_tab():tab_id()
				tab_names[id] = (line ~= "" and line or nil)
			end
		end),
	}) },

	-- Cycle tabs
	{ key = "Tab",  mods = "CTRL",       action = wezterm.action.ActivateTabRelative(1) },
	{ key = "Tab",  mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },

	-- Jump to last-used tab (toggle)
	{ key = "\\", mods = "ALT", action = wezterm.action_callback(function(window, pane)
		local prev = last_tab[window:window_id()]
		if prev then
			for _, t in ipairs(window:tabs()) do
				if t:tab_id() == prev then
					t:activate()
					break
				end
			end
		end
	end) },

	-- Fuzzy tab picker
	{ key = "/", mods = "ALT", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|TABS" }) },

	-- Shift+PageUp/Down reach the program: hoot's desk scrolls its own
	-- scrollback with them (WezTerm's would scroll a screen hoot redraws)
	{ key = "PageUp",   mods = "SHIFT", action = wezterm.action.DisableDefaultAssignment },
	{ key = "PageDown", mods = "SHIFT", action = wezterm.action.DisableDefaultAssignment },

	-- Tab movement
	{ key = "LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
	{ key = "PageUp",     mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
	{ key = "PageDown",   mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
	{ key = "H", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTabRelative(-1) },
	{ key = "L", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTabRelative(1) },

	-- Move tab to specific position
	{ key = "1", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTab(0) },
	{ key = "2", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTab(1) },
	{ key = "3", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTab(2) },
	{ key = "4", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTab(3) },
	{ key = "5", mods = "CTRL|SHIFT|ALT", action = wezterm.action.MoveTab(4) },

	-- Panes
	{ key = "d", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "CTRL|ALT",   action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "x", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane({ confirm = false }) },

	-- Direct tab access (Alt+number)
	{ key = "1", mods = "ALT", action = wezterm.action.ActivateTab(0) },
	{ key = "2", mods = "ALT", action = wezterm.action.ActivateTab(1) },
	{ key = "3", mods = "ALT", action = wezterm.action.ActivateTab(2) },
	{ key = "4", mods = "ALT", action = wezterm.action.ActivateTab(3) },
	{ key = "5", mods = "ALT", action = wezterm.action.ActivateTab(4) },
	{ key = "6", mods = "ALT", action = wezterm.action.ActivateTab(5) },
	{ key = "7", mods = "ALT", action = wezterm.action.ActivateTab(6) },
	{ key = "8", mods = "ALT", action = wezterm.action.ActivateTab(7) },
	{ key = "9", mods = "ALT", action = wezterm.action.ActivateTab(8) },

	-- Workspaces
	{ key = "S",   mods = "CTRL|ALT", action = wezterm.action.ShowLauncherArgs({ flags = "WORKSPACES" }) },
	{ key = " ",   mods = "CTRL|ALT", action = wezterm.action.ShowLauncherArgs({ flags = "WORKSPACES" }) },
	{ key = "M",   mods = "CTRL|ALT", action = wezterm.action.SwitchToWorkspace({ name = "main" }) },
	{ key = "D",   mods = "CTRL|ALT", action = wezterm.action.SwitchToWorkspace({ name = "dev" }) },
	{ key = "G",   mods = "CTRL|ALT", action = wezterm.action.SwitchToWorkspace({ name = "git" }) },
	{ key = "N",   mods = "CTRL|ALT", action = wezterm.action.PromptInputLine({
		description = "Enter name for new workspace",
		action = wezterm.action_callback(function(window, pane, line)
			if line then
				window:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), pane)
			end
		end),
	}) },

	-- Session save/restore
	{ key = "s", mods = "CTRL|ALT", action = wezterm.action_callback(function(window, pane)
		wezterm.emit("save-session", window, pane)
	end) },
	{ key = "r", mods = "CTRL|ALT", action = wezterm.action_callback(function(window, pane)
		wezterm.emit("restore-session", window, pane)
	end) },

	-- Close all tabs
	{ key = "Q", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(window, pane)
		for _, tab in ipairs(window:tabs()) do
			tab:activate()
			window:perform_action(wezterm.action.CloseCurrentTab({ confirm = false }), pane)
		end
	end) },
	{ key = "W", mods = "CTRL|SHIFT|ALT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
}

-- Cursor settings
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- Scrollback
config.scrollback_lines = 10000
config.enable_scroll_bar = false

-- Bell
config.audible_bell = "Disabled"

return config
