-- termite.nvim
-- Tmux-like tab bar shown while a terminal is maximized.

local config = require("termite.config")
local highlights = require("termite.highlights")
local state = require("termite.state")

local M = {}

local NS = vim.api.nvim_create_namespace("termite_tabs")

local VALID_POSITIONS = { top = true, right = true, bottom = true, left = true }

local MIN_TERM_WIDTH = 10
local MIN_TAB_WIDTH = 4
local HORIZONTAL_SEP = "  "

-- Click lookup for the currently rendered tab bar.
local tab_spans = {}
local tab_vertical = false

-- Helpers {{{

-- Validated tab bar side, defaulting to "right".
local function tab_position()
	local tc = config.values.tabs
	local pos = type(tc) == "table" and tc.position or "right"
	if not VALID_POSITIONS[pos] then
		return "right"
	end
	return pos
end

-- Editor dimensions, mirrored from layout/stack.lua.
local function editor_size()
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus > 0 then
		editor_height = editor_height - 1
	end
	if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
		editor_height = editor_height - 1
	end
	return editor_width, editor_height
end

-- Outer rect (exclusive bottom/right) of the maximized panel.
local function panel_rect()
	local editor_width, editor_height = editor_size()
	local position = config.values.position
	if position == "left" or position == "right" then
		local width = math.floor(editor_width * config.values.width)
		local outer = width + 1
		if position == "left" then
			return { top = 0, left = 0, bottom = editor_height, right = outer }
		end
		return { top = 0, left = editor_width - outer, bottom = editor_height, right = editor_width }
	end
	local height = math.floor(editor_height * config.values.height)
	local outer = height + 1
	if position == "top" then
		return { top = 0, left = 0, bottom = outer, right = editor_width }
	end
	return { top = editor_height - outer, left = 0, bottom = editor_height, right = editor_width }
end

-- Display title for a terminal: running process or cwd basename.
local function tab_title(term, max_title)
	local title = ""
	if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
		local ok, term_title = pcall(vim.api.nvim_buf_get_var, term.buf, "term_title")
		if ok and type(term_title) == "string" and term_title ~= "" then
			title = term_title
		end
	end
	if title == "" then
		title = term.cwd and vim.fn.fnamemodify(term.cwd, ":t") or ""
		if title == "" then
			title = "term"
		end
	end
	if vim.fn.strchars(title) > max_title then
		title = vim.fn.strcharpart(title, 0, math.max(max_title - 1, 1)) .. "…"
	end
	return title
end

-- Build "[index] title" labels for every terminal in the stack.
local function build_labels(max_title)
	local labels = {}
	for i, term in ipairs(state.terminals) do
		labels[i] = "[" .. i .. "] " .. tab_title(term, max_title)
	end
	return labels
end

-- Truncate every label so its display width fits max_width.
local function fit_labels(labels, max_width)
	local fitted = {}
	for i, label in ipairs(labels) do
		if vim.api.nvim_strwidth(label) > max_width then
			local title = vim.fn.strcharpart(label, 0, 1) == "[" and label:match("^%[%d+%] (.*)$") or label
			local prefix = label:match("^(%[%d+%] )") or ""
			local budget = math.max(max_width - vim.api.nvim_strwidth(prefix) - 1, 1)
			title = vim.fn.strcharpart(title, 0, budget) .. "…"
			fitted[i] = prefix .. title
		else
			fitted[i] = label
		end
	end
	return fitted
end

-- Width of a vertical tab bar for the given labels.
local function vertical_width(labels)
	local width = 0
	for _, label in ipairs(labels) do
		width = math.max(width, vim.api.nvim_strwidth(label))
	end
	return math.max(width + 2, 6)
end

-- }}}

-- Labels {{{

-- Current tab labels, for rendering and tests.
M.labels = function()
	local tc = config.values.tabs
	local max_title = type(tc) == "table" and tc.max_title_width or 20
	return build_labels(max_title or 20)
end

-- Whether the tab bar should be visible right now.
M.should_show = function()
	local tc = config.values.tabs
	if type(tc) ~= "table" or tc.enabled == false then
		return false
	end
	return state.maximized_idx ~= nil and #state.terminals > 1
end

-- Whether the tab window is currently open.
M.is_visible = function()
	return state.tab_win ~= nil and vim.api.nvim_win_is_valid(state.tab_win)
end

-- }}}

-- Geometry {{{

-- Compute tab bar rect, terminal size patch, rendered lines, and click spans.
-- Returns nil when there is not enough room for a usable tab bar.
M.compute = function()
	if not M.should_show() then
		return nil
	end
	local rect = panel_rect()
	local panel_width = rect.right - rect.left
	local panel_height = rect.bottom - rect.top
	local side = tab_position()
	local active = state.maximized_idx

	if side == "top" or side == "bottom" then
		local tc = config.values.tabs
		local max_title = type(tc) == "table" and tc.max_title_width or 20
		local labels = fit_labels(build_labels(max_title or 20), panel_width)
		local segments = {}
		for _, label in ipairs(labels) do
			table.insert(segments, " " .. label .. " ")
		end
		local line = table.concat(segments, HORIZONTAL_SEP):gsub("%s+$", "")
		if vim.api.nvim_strwidth(line) > panel_width then
			local excess = vim.api.nvim_strwidth(line) - panel_width
			local cut = math.ceil(excess / #labels)
			labels = fit_labels(build_labels(math.max((max_title or 20) - cut, 6)), panel_width)
			segments = {}
			for _, label in ipairs(labels) do
				table.insert(segments, " " .. label .. " ")
			end
			line = table.concat(segments, HORIZONTAL_SEP):gsub("%s+$", "")
		end
		if vim.api.nvim_strwidth(line) > panel_width then
			line = vim.fn.strcharpart(line, 0, panel_width)
		end
		local spans = {}
		local byte = 0
		for i, segment in ipairs(segments) do
			local from = byte
			byte = byte + #segment + (i < #segments and #HORIZONTAL_SEP or 0)
			if from < #line then
				table.insert(spans, { line = 1, from = from, to = math.min(byte, #line), idx = i })
			end
		end
		return {
			side = side,
			tab = { row = side == "top" and rect.top or rect.bottom - 1, col = rect.left, width = panel_width, height = 1 },
			term = { shrink = "height", amount = 1 },
			lines = { line },
			spans = spans,
			active = active,
		}
	end

	local tc = config.values.tabs
	local max_title = type(tc) == "table" and tc.max_title_width or 20
	local labels = build_labels(max_title or 20)
	local width = math.min(vertical_width(labels), panel_width - MIN_TERM_WIDTH - 1)
	if width < MIN_TAB_WIDTH then
		return nil
	end
	labels = fit_labels(labels, width - 2)
	local lines = {}
	local spans = {}
	for i, label in ipairs(labels) do
		local padded = " " .. label
		lines[i] = padded
		table.insert(spans, { line = i, from = 0, to = #padded, idx = i })
	end
	for i = #labels + 1, panel_height do
		lines[i] = ""
	end
	local col = side == "left" and rect.left or rect.right - width
	return {
		side = side,
		tab = { row = rect.top, col = col, width = width, height = panel_height },
		term = { shrink = "width", amount = width },
		lines = lines,
		spans = spans,
		active = active,
	}
end

-- Size/position patch for the maximized terminal window config, reserving
-- room for the tab bar. Returns an empty table when tabs are hidden.
M.term_patch = function(full)
	local info = M.compute()
	if not info then
		return {}
	end
	local patch = {}
	local anchor = full.anchor
	if info.term.shrink == "height" then
		local amount = info.term.amount
		patch.height = math.max(full.height - amount, 1)
		if info.side == "top" and (anchor == "NW" or anchor == "NE") then
			patch.row = full.row + amount
		elseif info.side == "bottom" and anchor == "SW" then
			patch.row = full.row - amount
		end
	else
		local amount = info.term.amount
		patch.width = math.max(full.width - amount, MIN_TERM_WIDTH)
		if info.side == "left" and (anchor == "NW" or anchor == "SW") then
			patch.col = full.col + amount
		elseif info.side == "right" and anchor == "NE" then
			patch.col = full.col - amount
		end
	end
	return patch
end

-- }}}

-- Window {{{

-- Ensure the backing buffer exists and return it.
local function ensure_buf()
	if not (state.tab_buf and vim.api.nvim_buf_is_valid(state.tab_buf)) then
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].modifiable = false
		vim.b[buf].termite_tabs = true
		vim.keymap.set("n", "<LeftRelease>", function()
			M.on_click()
		end, { buffer = buf, desc = "Termite: Select tab" })
		state.tab_buf = buf
	end
	return state.tab_buf
end

-- Render (or hide) the tab bar to match current state.
M.update = function()
	local info = M.compute()
	if not info then
		M.hide()
		return
	end
	local buf = ensure_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, info.lines)
	vim.bo[buf].modifiable = false

	local win_config = {
		anchor = "NW",
		border = "none",
		col = info.tab.col,
		focusable = true,
		height = info.tab.height,
		relative = "editor",
		row = info.tab.row,
		style = "minimal",
		width = info.tab.width,
		zindex = 60,
	}
	if M.is_visible() then
		vim.api.nvim_win_set_config(state.tab_win, win_config)
	else
		local ok, win = pcall(vim.api.nvim_open_win, buf, false, win_config)
		if not ok then
			return
		end
		state.tab_win = win
	end
	vim.wo[state.tab_win].winbar = ""
	vim.wo[state.tab_win].wrap = false

	vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
	local hl_active = highlights.resolve_hl(config.values.highlights.tab_active, highlights.TAB_ACTIVE)
	local hl_inactive = highlights.resolve_hl(config.values.highlights.tab_inactive, highlights.TAB_INACTIVE)
	for _, span in ipairs(info.spans) do
		local hl = span.idx == info.active and hl_active or hl_inactive
		vim.api.nvim_buf_add_highlight(buf, NS, hl, span.line - 1, span.from, span.to)
	end
	pcall(vim.api.nvim_win_set_cursor, state.tab_win, { math.min(info.active, #info.lines), 0 })

	tab_spans = info.spans
	tab_vertical = info.side == "left" or info.side == "right"
end

-- Close the tab bar window, keeping the buffer for reuse.
M.hide = function()
	if M.is_visible() then
		vim.api.nvim_win_close(state.tab_win, true)
	end
	state.tab_win = nil
	tab_spans = {}
end

-- }}}

-- Click {{{

-- Map a mouse position to a terminal index. Exposed for tests.
M.resolve_index = function(is_vertical, line, col, count)
	if is_vertical then
		if line >= 1 and line <= count then
			return line
		end
		return nil
	end
	for _, span in ipairs(tab_spans) do
		if col >= span.from and col < span.to then
			return span.idx
		end
	end
	return nil
end

-- Jump to the tab under the mouse cursor.
M.on_click = function()
	local ok, pos = pcall(vim.fn.getmousepos)
	if not ok or type(pos) ~= "table" then
		return
	end
	if pos.winid ~= state.tab_win then
		return
	end
	local idx = M.resolve_index(tab_vertical, pos.line or 0, (pos.column or 1) - 1, #state.terminals)
	if idx then
		require("termite").focus_index(idx)
	end
end

-- }}}

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
