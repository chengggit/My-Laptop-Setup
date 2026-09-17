-- termite.nvim
-- Configuration defaults and setup.

local BORDER_STYLES = require("termite.borders")

local M = {}

local DEFAULTS = {
	width = 0.5, -- Fraction of editor width (for left/right positions).
	height = 0.5, -- Fraction of editor height (for top/bottom positions).
	position = "right", -- Panel position: "left", "right", "top", or "bottom".
	border = "light", -- Border style: "light", "heavy", "double", "double-dash", "triple-dash", "quadruple-dash".
	shell = nil, -- Shell command (nil = default shell).
	start_insert = true, -- Enter insert mode when focusing a terminal.
	click_to_insert = true, -- Enter insert mode when clicking a terminal window.
	winbar = true, -- Show winbar with cwd and running process.
	tabs = {
		enabled = true, -- Show tmux-like tab bar while a terminal is maximized.
		position = "right", -- Tab bar side: "top", "right", "bottom", or "left".
		max_title_width = 20, -- Max display width for the process title in tabs.
	},
	keymaps = {
		toggle = "<c-bslash>", -- Toggle all terminals (terminal mode).
		create = "<c-t>", -- Create new terminal.
		next = "<c-n>", -- Focus next terminal in stack.
		prev = "<c-p>", -- Focus previous terminal in stack.
		focus_editor = "<c-e>", -- Return focus to editor window.
		normal_mode = "<c-[>", -- Exit terminal insert mode.
		maximize = "<c-z>", -- Maximize/restore focused terminal.
		close = "q", -- Close current terminal (normal mode).
		goto_1 = nil, -- Jump to terminal 1 (e.g. "<A-1>").
		goto_2 = nil, -- Jump to terminal 2 (e.g. "<A-2>").
		goto_3 = nil, -- Jump to terminal 3 (e.g. "<A-3>").
		goto_4 = nil, -- Jump to terminal 4 (e.g. "<A-4>").
		goto_5 = nil, -- Jump to terminal 5 (e.g. "<A-5>").
	},
	wo = { -- Window options applied to terminal windows.
		signcolumn = "yes:1",
	},
	highlights = {
		border_active = "TermiteBorder", -- Highlight for active terminal border (string = hl group, table = direct definition).
		border_inactive = "TermiteBorderNC", -- Highlight for inactive terminal borders (string = hl group, table = direct definition).
		border_single = "TermiteBorderSingle", -- Highlight for single terminal border (string = hl group, table = direct definition).
		winbar = "TermiteWinbar", -- Highlight for winbar.
		tab_active = "TermiteTabActive", -- Highlight for the selected tab in the maximized tab bar.
		tab_inactive = "TermiteTabInactive", -- Highlight for unselected tabs in the maximized tab bar.
	},
}

M.values = vim.deepcopy(DEFAULTS)

M.setup = function(opts)
	M.values = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
end

M.get_border_chars = function()
	return BORDER_STYLES[M.values.border] or BORDER_STYLES.light
end

return M
