-- termite.nvim
-- Stacking float terminal manager for Neovim.
--
-- Public API:
--   require("termite").setup(opts)          Configure the plugin.
--   require("termite").toggle()             Toggle all terminals (show/hide).
--   require("termite").create()             Create a new terminal.
--   require("termite").focus_next()         Focus next terminal in stack.
--   require("termite").focus_prev()         Focus previous terminal in stack.
--   require("termite").focus_editor()       Focus editor window.
--   require("termite").focus_terminals()    Focus the terminal stack.
--   require("termite").close_current()      Close the focused terminal.
--   require("termite").toggle_maximize()    Maximize/restore focused terminal.
--   require("termite").focus_index(idx)     Focus terminal by stack index.
--   require("termite").refresh_maximized()  Re-apply maximized layout and tabs.
--   require("termite").reflow()             Re-sync all window geometry.

local config = require("termite.config")
local highlights = require("termite.highlights")
local layout = require("termite.layout")
local state = require("termite.state")
local tabs = require("termite.tabs")
local terminal = require("termite.terminal")

local M = {}

-- Configuration {{{

M.setup = function(opts)
	config.setup(opts)

	-- Set up highlights AFTER config is merged, so user values are available.
	highlights.setup()

	local km = config.values.keymaps
	if km.toggle then
		vim.keymap.set("n", km.toggle, function()
			M.toggle()
		end, { desc = "Termite: Toggle" })
	end
	if km.create then
		vim.keymap.set("n", km.create, function()
			M.create()
		end, { desc = "Termite: Create" })
	end
	for i = 1, 5 do
		local lhs = km["goto_" .. i]
		if lhs then
			local target = i
			vim.keymap.set("n", lhs, function()
				M.focus_index(target)
			end, { desc = "Termite: Goto " .. target })
		end
	end
end

-- }}}

-- Helpers {{{

-- Find the index of the currently focused terminal.
local function get_focused_index()
	local current_win = vim.api.nvim_get_current_win()
	for i, term in ipairs(state.terminals) do
		if term.win == current_win then
			return i
		end
	end
	return nil
end

-- Store the current window as the last editor window (if it's not a terminal).
local function save_editor_window()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local bt = vim.bo[buf].buftype
	if bt ~= "terminal" and not vim.b[buf].termite_tabs then
		state.last_editor_winnr = win
	end
end

-- Update border highlights for all terminals based on focus.
-- While maximized, show only the single outer-edge border.
local function update_border_highlights()
	if state.maximized_idx then
		local maximized = state.terminals[state.maximized_idx]
		if maximized and maximized.win and vim.api.nvim_win_is_valid(maximized.win) then
			layout.update_border_highlight(maximized, 1, 1, "single")
		end
		return
	end
	local current_win = vim.api.nvim_get_current_win()
	for i, term in ipairs(state.terminals) do
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			local hl_type
			if #state.terminals == 1 then
				hl_type = "single"
			elseif term.win == current_win then
				hl_type = "active"
			else
				hl_type = "inactive"
			end
			layout.update_border_highlight(term, i, #state.terminals, hl_type)
		end
	end
end

-- Restore all hidden siblings when exiting maximized state. Used by multiple actions.
local function restore_from_maximized()
	tabs.hide()
	state.maximized_idx = nil
	state.last_maximized_idx = nil
	for i, term in ipairs(state.terminals) do
		if not term.win or not vim.api.nvim_win_is_valid(term.win) then
			local win_config = layout.get_win_config(i, #state.terminals)
			term.config = win_config
			terminal.show(term)
		end
	end
	update_border_highlights()
end

-- Focus the saved editor window.
local function focus_editor_window()
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
	end
end

-- Apply maximized geometry to a terminal, reserving room for the tab bar.
-- The maximized terminal keeps only the single outer-edge border.
local function apply_maximized_config(term)
	local win_config = layout.get_win_config(1, 1)
	term.config = vim.tbl_extend("force", win_config, tabs.term_patch(win_config))
	if not (term.win and vim.api.nvim_win_is_valid(term.win)) then
		terminal.show(term)
	else
		layout.apply_config(term, term.config)
	end
end

-- Swap the maximized view to another terminal in the stack.
local function switch_maximized(new_idx)
	local current = state.terminals[state.maximized_idx]
	local next_term = state.terminals[new_idx]
	if not next_term then
		return
	end
	if current and current ~= next_term then
		terminal.hide(current)
	end
	state.maximized_idx = new_idx
	state.last_focused_idx = new_idx
	apply_maximized_config(next_term)
	if next_term.win and vim.api.nvim_win_is_valid(next_term.win) then
		vim.api.nvim_set_current_win(next_term.win)
	end
	tabs.update()
	update_border_highlights()
	if config.values.start_insert then
		vim.cmd.startinsert()
	end
end

-- }}}

-- Terminal actions {{{

-- Remove a terminal from the stack by reference and reflow remaining.
-- NOTE: Called from BufWipeout autocmd (e.g., when shell process exits).
M.remove_terminal = function(term)
	local removed_idx = nil
	for i, t in ipairs(state.terminals) do
		if t == term then
			removed_idx = i
			table.remove(state.terminals, i)
			break
		end
	end

	-- If the maximized terminal was removed, stay maximized on a neighbor.
	-- Otherwise refresh tab labels since indices may have shifted.
	if state.maximized_idx then
		if removed_idx and removed_idx == state.maximized_idx then
			if #state.terminals == 0 then
				tabs.hide()
				state.maximized_idx = nil
				state.last_maximized_idx = nil
			else
				switch_maximized(math.min(removed_idx, #state.terminals))
			end
		elseif removed_idx then
			if removed_idx < state.maximized_idx then
				state.maximized_idx = state.maximized_idx - 1
			end
			tabs.update()
		end
		if #state.terminals == 0 then
			state.visible = false
			state.last_maximized_idx = nil
			focus_editor_window()
		end
		return
	end

	-- Keep the remembered maximized index in sync when terminals are
	-- removed while hidden.
	if state.last_maximized_idx then
		if removed_idx and removed_idx == state.last_maximized_idx then
			state.last_maximized_idx = math.min(removed_idx, #state.terminals)
			if #state.terminals == 0 then
				state.last_maximized_idx = nil
			end
		elseif removed_idx and removed_idx < state.last_maximized_idx then
			state.last_maximized_idx = state.last_maximized_idx - 1
		end
	end

	if #state.terminals == 0 then
		state.visible = false
		state.last_maximized_idx = nil
		focus_editor_window()
	elseif state.visible then
		layout.reflow()
		local focus_idx = removed_idx and removed_idx > 1 and removed_idx - 1 or 1
		focus_idx = math.min(focus_idx, #state.terminals)
		local focus_term = state.terminals[focus_idx]
		if focus_term and focus_term.win and vim.api.nvim_win_is_valid(focus_term.win) then
			vim.api.nvim_set_current_win(focus_term.win)
		end
		update_border_highlights()
	end
end

-- Show all hidden terminals.
local function show_all()
	tabs.hide()
	state.maximized_idx = nil
	for i, term in ipairs(state.terminals) do
		local win_config = layout.get_win_config(i, #state.terminals)
		term.config = win_config
		if not term.win or not vim.api.nvim_win_is_valid(term.win) then
			terminal.show(term)
		end
	end

	state.visible = true
	layout.reflow()

	-- Focus the most recently focused terminal, or fall back to the last in the stack.
	if #state.terminals > 0 then
		local focus_idx = state.last_focused_idx or #state.terminals
		focus_idx = math.min(focus_idx, #state.terminals)
		local term = state.terminals[focus_idx]
		if term and term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_set_current_win(term.win)
			state.last_focused_idx = focus_idx
			update_border_highlights()
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
	end

	-- Restore the remembered maximized view, if it is still valid.
	if state.last_maximized_idx and state.last_maximized_idx <= #state.terminals then
		for i, term in ipairs(state.terminals) do
			if i ~= state.last_maximized_idx then
				terminal.hide(term)
			end
		end
		switch_maximized(state.last_maximized_idx)
	end
end

-- Hide all terminals. The maximized terminal is remembered so toggling
-- back on restores the maximized view instead of the split layout.
local function hide_all()
	tabs.hide()
	state.last_maximized_idx = state.maximized_idx
	state.maximized_idx = nil
	for _, term in ipairs(state.terminals) do
		terminal.hide(term)
	end

	state.visible = false

	-- Return to the last editor window.
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
	end
end

-- }}}

-- Public API {{{

-- Toggle all terminals (show/hide). First call creates one.
-- Smart behavior: if terminals visible but focus is on editor, focus terminals instead of hiding.
M.toggle = function()
	save_editor_window()

	if state.visible and #state.terminals > 0 then
		-- Check if any terminal window is actually open.
		local any_visible = false
		for _, term in ipairs(state.terminals) do
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				any_visible = true
				break
			end
		end

		if any_visible then
			-- Check if focus is currently on a terminal
			local focused_idx = get_focused_index()
			if focused_idx then
				-- Focus is on a terminal, hide them
				hide_all()
			else
				-- Focus is on editor, focus terminals instead
				M.focus_terminals()
			end
		else
			show_all()
		end
	elseif #state.terminals > 0 then
		show_all()
	else
		terminal.create()
		state.last_focused_idx = #state.terminals
		update_border_highlights()
	end
end

-- Create a new terminal and add it to the stack.
-- While maximized, the new terminal is appended to the tab bar and becomes
-- the maximized view instead of restoring the split layout.
M.create = function()
	if state.maximized_idx then
		local hidden = terminal.create({ hidden = true })
		if hidden then
			switch_maximized(#state.terminals)
		end
		return hidden
	end

	-- Entering split mode: forget any remembered maximized terminal.
	state.last_maximized_idx = nil

	-- Show existing hidden terminals before creating a new one.
	if #state.terminals > 0 and not state.visible then
		state.visible = true
		for _, term in ipairs(state.terminals) do
			if not term.win or not vim.api.nvim_win_is_valid(term.win) then
				terminal.show(term)
			end
		end
	end

	local term = terminal.create()
	state.last_focused_idx = #state.terminals
	update_border_highlights()
	return term
end

-- Focus the next terminal in the stack (wraps around).
-- While maximized, cycles the maximized view instead.
M.focus_next = function()
	if #state.terminals == 0 then
		return
	end

	if state.maximized_idx then
		local idx = get_focused_index() or state.maximized_idx
		switch_maximized(idx % #state.terminals + 1)
		return
	end

	local idx = get_focused_index()
	if not idx then
		return
	end

	local next_idx = idx % #state.terminals + 1
	local term = state.terminals[next_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_idx = next_idx
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Focus the previous terminal in the stack (wraps around).
-- While maximized, cycles the maximized view instead.
M.focus_prev = function()
	if #state.terminals == 0 then
		return
	end

	if state.maximized_idx then
		local idx = get_focused_index() or state.maximized_idx
		switch_maximized((idx - 2) % #state.terminals + 1)
		return
	end

	local idx = get_focused_index()
	if not idx then
		return
	end

	local prev_idx = (idx - 2) % #state.terminals + 1
	local term = state.terminals[prev_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_idx = prev_idx
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Focus the editor window, keeping terminals visible.
M.focus_editor = function()
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
		update_border_highlights()
		return
	end

	-- Fallback: find any non-terminal, non-floating window.
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.bo[buf].buftype
		local win_config = vim.api.nvim_win_get_config(win)
		if bt ~= "terminal" and win_config.relative == "" then
			vim.api.nvim_set_current_win(win)
			update_border_highlights()
			return
		end
	end
end

-- Focus the terminal stack (focuses the last focused terminal, or the last in the stack).
M.focus_terminals = function()
	if not state.visible or #state.terminals == 0 then
		return
	end

	if state.maximized_idx then
		local maximized = state.terminals[state.maximized_idx]
		if maximized and maximized.win and vim.api.nvim_win_is_valid(maximized.win) then
			vim.api.nvim_set_current_win(maximized.win)
			update_border_highlights()
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
		return
	end

	local focus_idx = state.last_focused_idx or #state.terminals
	focus_idx = math.min(focus_idx, #state.terminals)
	local term = state.terminals[focus_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Close the currently focused terminal and remove it from the stack.
M.close_current = function()
	local idx = get_focused_index()
	if not idx then
		return
	end

	local was_maximized = state.maximized_idx == idx
	local term = state.terminals[idx]

	-- Determine which terminal to focus after closing.
	local next_idx = nil
	if #state.terminals > 1 then
		next_idx = idx <= #state.terminals - 1 and idx or idx - 1
	end

	-- Remove from stack first, then close.
	table.remove(state.terminals, idx)
	if was_maximized then
		state.maximized_idx = nil
	elseif state.maximized_idx and idx < state.maximized_idx then
		state.maximized_idx = state.maximized_idx - 1
	end
	terminal.close(term)

	if #state.terminals == 0 then
		state.visible = false
		state.last_maximized_idx = nil
		if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
			vim.api.nvim_set_current_win(state.last_editor_winnr)
		end
	elseif state.visible then
		-- If the maximized terminal was closed, stay maximized on a neighbor.
		if was_maximized then
			state.maximized_idx = math.min(next_idx or 1, #state.terminals)
			for i, t in ipairs(state.terminals) do
				if i ~= state.maximized_idx then
					terminal.hide(t)
				end
			end
			state.last_focused_idx = state.maximized_idx
			local current = state.terminals[state.maximized_idx]
			if current then
				apply_maximized_config(current)
				if current.win and vim.api.nvim_win_is_valid(current.win) then
					vim.api.nvim_set_current_win(current.win)
				end
			end
			tabs.update()
			update_border_highlights()
			return
		end
		layout.reflow()
		if next_idx then
			local next_term = state.terminals[next_idx]
			if next_term and next_term.win and vim.api.nvim_win_is_valid(next_term.win) then
				vim.api.nvim_set_current_win(next_term.win)
			end
		end
		update_border_highlights()
	end
end

-- Maximize the focused terminal or restore if already maximized.
M.toggle_maximize = function()
	local idx = get_focused_index()
	if not idx then
		if state.maximized_idx then
			idx = state.maximized_idx
		else
			return
		end
	end

	if state.maximized_idx then
		-- Restore: re-show all hidden siblings.
		restore_from_maximized()
		layout.reflow()
		-- Re-focus the terminal that was maximized.
		local term = state.terminals[idx]
		if term and term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_set_current_win(term.win)
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
		update_border_highlights()
	else
		-- Maximize: hide all siblings, expand focused terminal to fill the
		-- panel (reserving room for the tab bar).
		state.maximized_idx = idx
		for i, term in ipairs(state.terminals) do
			if i ~= idx then
				terminal.hide(term)
			end
		end
		local term = state.terminals[idx]
		if term then
			apply_maximized_config(term)
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
		tabs.update()
		update_border_highlights()
	end
end

-- Focus a terminal by stack index. While maximized, swaps the maximized view.
-- Shows hidden terminals first so jumping always lands on the target.
M.focus_index = function(idx)
	if type(idx) ~= "number" or idx < 1 or idx > #state.terminals then
		return
	end

	if state.maximized_idx then
		if idx ~= state.maximized_idx then
			switch_maximized(idx)
		else
			local current = state.terminals[idx]
			if current and current.win and vim.api.nvim_win_is_valid(current.win) then
				vim.api.nvim_set_current_win(current.win)
			end
		end
		return
	end

	if not state.visible then
		show_all()
	end

	local term = state.terminals[idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_idx = idx
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Re-apply maximized geometry and refresh the tab bar. Used after VimResized.
M.refresh_maximized = function()
	if not state.maximized_idx then
		return
	end
	if state.reflowing then
		return
	end
	state.reflowing = true
	local ok, err = pcall(function()
		local term = state.terminals[state.maximized_idx]
		if not (term and term.win and vim.api.nvim_win_is_valid(term.win)) then
			return
		end
		apply_maximized_config(term)
		tabs.update()
		update_border_highlights()
	end)
	state.reflowing = false
	if not ok then
		error(err)
	end
end

-- Re-sync all terminal window geometry with the current editor size.
-- Repairs floats left stale by external changes (e.g. closed or moved windows).
M.reflow = function()
	if state.reflowing then
		return
	end
	state.reflowing = true
	local ok, err = pcall(function()
		if state.maximized_idx then
			local term = state.terminals[state.maximized_idx]
			if term and term.win and vim.api.nvim_win_is_valid(term.win) then
				apply_maximized_config(term)
				tabs.update()
				update_border_highlights()
			end
			return
		end
		if not state.visible or #state.terminals == 0 then
			return
		end
		for i, term in ipairs(state.terminals) do
			if not term.win or not vim.api.nvim_win_is_valid(term.win) then
				local win_config = layout.get_win_config(i, #state.terminals)
				term.config = win_config
				terminal.show(term)
			end
		end
		layout.reflow()
		update_border_highlights()
		tabs.update()
	end)
	state.reflowing = false
	if not ok then
		error(err)
	end
end

-- Dynamically adjust side panel width (for left/right position)
M.resize_width = function(delta)
	local opts = config.values
	opts.width = math.max(0.1, math.min(0.9, (opts.width or 0.4) + delta))
	M.reflow()
end

-- Dynamically adjust panel height (for top/bottom position)
M.resize_height = function(delta)
	local opts = config.values
	opts.height = math.max(0.1, math.min(0.9, (opts.height or 0.3) + delta))
	M.reflow()
end

-- Smart resize helper based on active position
M.resize = function(delta)
	local position = config.values.position
	if position == "left" or position == "right" then
		M.resize_width(delta)
	else
		M.resize_height(delta)
	end
end

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
