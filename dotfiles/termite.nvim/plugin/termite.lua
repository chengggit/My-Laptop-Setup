-- termite.nvim
-- Autoloaded: autocmds and user commands.

local group = vim.api.nvim_create_augroup("termite/plugin", { clear = true })

-- Reflow or reposition terminals when the editor is resized.
-- NOTE: Full reflow (geometry + borders + tabs) so every panel stays in
-- sync instead of only the focused one.
vim.api.nvim_create_autocmd("VimResized", {
	group = group,
	callback = function()
		local state = require("termite.state")
		if not state.visible or #state.terminals == 0 then
			return
		end
		if state.reflowing then
			return
		end
		vim.schedule(function()
			local ok, termite = pcall(require, "termite")
			if ok and termite then
				pcall(termite.reflow)
			end
		end)
	end,
})

-- Restore the whole stack when a single floating panel is resized directly.
-- NOTE: Without this, resizing one panel (mouse drag, :resize, <C-w>+/-, etc.)
-- leaves siblings stale and the panel looks broken. The re-entrancy guard in
-- termite.reflow() prevents our own geometry updates from looping here.
vim.api.nvim_create_autocmd("WinResized", {
	group = group,
	callback = function()
		local state = require("termite.state")
		if not state.visible or #state.terminals == 0 then
			return
		end
		if state.reflowing then
			return
		end
		local event = vim.v.event or {}
		local resized = event.windows or {}
		if #resized == 0 then
			return
		end
		local lookup = {}
		for _, winid in ipairs(resized) do
			lookup[winid] = true
		end
		local needs_reflow = false
		for _, term in ipairs(state.terminals) do
			if term.win and lookup[term.win] then
				needs_reflow = true
				break
			end
		end
		if not needs_reflow and state.tab_win and lookup[state.tab_win] then
			needs_reflow = true
		end
		if not needs_reflow then
			return
		end
		vim.schedule(function()
			local ok, termite = pcall(require, "termite")
			if ok and termite then
				pcall(termite.reflow)
			end
		end)
	end,
})

-- Update border highlights when entering a terminal window.
vim.api.nvim_create_autocmd("WinEnter", {
	group = group,
	callback = function()
		local state = require("termite.state")
		local layout = require("termite.layout")
		if not state.visible or #state.terminals == 0 then
			return
		end

		-- While maximized, keep only the single outer-edge border.
		if state.maximized_idx then
			local current_win = vim.api.nvim_get_current_win()
			local maximized = state.terminals[state.maximized_idx]
			if maximized and maximized.win == current_win and vim.api.nvim_win_is_valid(maximized.win) then
				layout.update_border_highlight(maximized, 1, 1, "single")
			end
			return
		end

		local current_win = vim.api.nvim_get_current_win()
		local is_termite_terminal = false
		for _, term in ipairs(state.terminals) do
			if term.win == current_win then
				is_termite_terminal = true
				break
			end
		end

		if is_termite_terminal then
			local current_win_id = vim.api.nvim_get_current_win()
			for i, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					local hl_type
					if #state.terminals == 1 then
						hl_type = "single"
					elseif term.win == current_win_id then
						hl_type = "active"
					else
						hl_type = "inactive"
					end
					layout.update_border_highlight(term, i, #state.terminals, hl_type)
				end
			end
		end
	end,
})

-- Refresh maximized tab bar titles when terminal state may have changed.
vim.api.nvim_create_autocmd({ "BufEnter", "TermEnter", "TermOpen", "DirChanged" }, {
	group = group,
	callback = function()
		local state = require("termite.state")
		if not state.maximized_idx or #state.terminals < 2 then
			return
		end
		require("termite.tabs").update()
	end,
})

-- User commands.
local SUBCOMMANDS = {
	toggle = "toggle",
	create = "create",
	maximize = "toggle_maximize",
	close = "close_current",
	next = "focus_next",
	prev = "focus_prev",
	editor = "focus_editor",
	terminals = "focus_terminals",
	goto = "focus_index",
	reflow = "reflow",
}

vim.api.nvim_create_user_command("Termite", function(opts)
	local termite = require("termite")
	local subcmd = opts.fargs[1] or "toggle"
	if subcmd == "goto" then
		termite.focus_index(tonumber(opts.fargs[2]))
		return
	end
	local fn_name = SUBCOMMANDS[subcmd]
	if fn_name and termite[fn_name] then
		termite[fn_name]()
	else
		vim.notify("Termite: unknown command '" .. subcmd .. "'", vim.log.levels.WARN)
	end
end, {
	nargs = "*",
	complete = function(_, cmdline, _)
		local parts = vim.split(vim.trim(cmdline), "%s+", { trimempty = true })
		if #parts >= 2 and parts[2] == "goto" then
			local indices = {}
			for i = 1, #require("termite.state").terminals do
				table.insert(indices, tostring(i))
			end
			return indices
		end
		return vim.tbl_keys(SUBCOMMANDS)
	end,
	desc = "Termite: stacking float terminal manager",
})
