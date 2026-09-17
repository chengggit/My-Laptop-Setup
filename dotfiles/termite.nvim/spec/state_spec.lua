-- termite.nvim
-- State management tests

describe("state management", function()
	local termite
	local state

	before_each(function()
		-- Reset all termite modules to get fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.layout.stack"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.tabs"] = nil
		package.loaded["termite.init"] = nil
		package.loaded["termite"] = nil

		termite = require("termite.init")
		state = require("termite.state")

		-- Setup with default config
		termite.setup()

		-- Create a non-terminal buffer to serve as editor window
		local editor_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(editor_buf)
	end)

	after_each(function()
		require("termite.tabs").hide()
		-- Clean up any remaining terminal windows and buffers
		for _, term in ipairs(state.terminals) do
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				vim.api.nvim_win_close(term.win, true)
			end
			if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
				vim.api.nvim_buf_delete(term.buf, { force = true })
			end
		end
		if state.tab_buf and vim.api.nvim_buf_is_valid(state.tab_buf) then
			vim.api.nvim_buf_delete(state.tab_buf, { force = true })
		end
		state.terminals = {}
		state.visible = false
		state.maximized_idx = nil
		state.last_maximized_idx = nil
		state.last_focused_idx = nil
		state.tab_win = nil
		state.tab_buf = nil
		state.next_count = 1
	end)

	describe("initial state", function()
		it("has correct default values", function()
			assert.are.same({}, state.terminals)
			assert.are.equal(false, state.visible)
			assert.are.equal(nil, state.maximized_idx)
			assert.are.equal(nil, state.last_editor_winnr)
			assert.are.equal(nil, state.last_focused_idx)
			assert.are.equal(1, state.next_count)
		end)
	end)

	describe("terminal creation", function()
		it("increments next_count on each create", function()
			assert.are.equal(1, state.next_count)

			termite.create()
			assert.are.equal(2, state.next_count)

			termite.create()
			assert.are.equal(3, state.next_count)
		end)

		it("adds terminal to terminals list", function()
			assert.are.equal(0, #state.terminals)

			termite.create()
			assert.are.equal(1, #state.terminals)
			assert.is_not_nil(state.terminals[1])
			assert.is_not_nil(state.terminals[1].buf)
			assert.is_not_nil(state.terminals[1].win)
		end)

		it("sets visible to true after creation", function()
			assert.are.equal(false, state.visible)

			termite.create()
			assert.are.equal(true, state.visible)
		end)

		it("sets last_focused_idx to new terminal", function()
			assert.are.equal(nil, state.last_focused_idx)

			termite.create()
			assert.are.equal(1, state.last_focused_idx)

			termite.create()
			assert.are.equal(2, state.last_focused_idx)
		end)
	end)

	describe("terminal removal", function()
		it("removes terminal from list on close_current", function()
			termite.create()
			termite.create()
			assert.are.equal(2, #state.terminals)

			termite.close_current()
			assert.are.equal(1, #state.terminals)
		end)

		it("sets visible to false when last terminal closed", function()
			termite.create()
			assert.are.equal(true, state.visible)

			termite.close_current()
			assert.are.equal(false, state.visible)
		end)

		it("preserves last_focused_idx when closing terminal", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			-- close_current focuses the window but does not update last_focused_idx
			termite.close_current()
			assert.are.equal(3, state.last_focused_idx)
		end)

		it("stays maximized on a neighbor when closing the maximized terminal itself", function()
			termite.create()
			termite.create()
			termite.create()

			-- Maximize the third terminal
			termite.toggle_maximize()
			assert.are.equal(3, state.maximized_idx)

			-- Close the maximized terminal (terminal 3)
			termite.close_current()

			-- maximized view moves to the neighbor instead of restoring
			assert.are.equal(2, state.maximized_idx)
			assert.are.equal(2, #state.terminals)
		end)
	end)

	describe("toggle visibility", function()
		it("toggles visible state", function()
			termite.create()
			assert.are.equal(true, state.visible)

			termite.toggle()
			assert.are.equal(false, state.visible)

			termite.toggle()
			assert.are.equal(true, state.visible)
		end)

		it("clears maximized_idx on hide", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.toggle()
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("saves last_editor_winnr when toggling from editor", function()
			local editor_win = vim.api.nvim_get_current_win()
			assert.are.equal(nil, state.last_editor_winnr)

			-- toggle() saves editor window before showing terminals
			termite.toggle()
			assert.are.equal(editor_win, state.last_editor_winnr)
		end)
	end)

	describe("focus management", function()
		it("updates last_focused_idx on focus_next", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			termite.focus_next()
			assert.are.equal(1, state.last_focused_idx)

			termite.focus_next()
			assert.are.equal(2, state.last_focused_idx)
		end)

		it("updates last_focused_idx on focus_prev", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			termite.focus_prev()
			assert.are.equal(2, state.last_focused_idx)

			termite.focus_prev()
			assert.are.equal(1, state.last_focused_idx)
		end)

		it("preserves last_focused_idx across hide/show", function()
			termite.create()
			termite.create()
			assert.are.equal(2, state.last_focused_idx)

			termite.toggle()
			assert.are.equal(2, state.last_focused_idx)

			termite.toggle()
			assert.are.equal(2, state.last_focused_idx)
		end)

		it("shows hidden terminals when jumping with focus_index", function()
			termite.create()
			termite.create()
			termite.toggle()
			assert.are.equal(false, state.visible)

			termite.focus_index(1)
			assert.are.equal(true, state.visible)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
			assert.are.equal(1, state.last_focused_idx)
		end)

		it("ignores out-of-range focus_index", function()
			termite.create()
			termite.focus_index(9)
			assert.are.equal(1, state.last_focused_idx)
		end)
	end)

	describe("maximize state", function()
		it("sets maximized_idx when maximizing", function()
			termite.create()
			assert.are.equal(nil, state.maximized_idx)

			termite.toggle_maximize()
			assert.are.equal(1, state.maximized_idx)
		end)

		it("clears maximized_idx when restoring", function()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(1, state.maximized_idx)

			termite.toggle_maximize()
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("appends to the maximized view when creating a new terminal", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.create()
			assert.are.equal(3, #state.terminals)
			assert.are.equal(3, state.maximized_idx)
			assert.are.equal(state.terminals[3].win, vim.api.nvim_get_current_win())
		end)

		it("cycles focus_next through the maximized view when maximized", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.focus_next()
			assert.are.equal(1, state.maximized_idx)
			assert.are.equal(1, state.last_focused_idx)
		end)

		it("cycles focus_prev through the maximized view when maximized", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.focus_prev()
			assert.are.equal(1, state.maximized_idx)
			assert.are.equal(1, state.last_focused_idx)
		end)
	end)

	describe("edge cases", function()
		it("handles closing the maximized terminal", function()
			termite.create()
			termite.create()
			termite.create()

			termite.toggle_maximize()
			assert.are.equal(3, state.maximized_idx)

			termite.close_current()
			assert.are.equal(2, state.maximized_idx)
			assert.are.equal(2, #state.terminals)
		end)

		it("handles rapid create/close cycles", function()
			termite.create()
			termite.create()
			termite.close_current()
			termite.create()
			termite.create()
			termite.close_current()
			termite.close_current()

			assert.are.equal(1, #state.terminals)
			assert.are.equal(true, state.visible)
		end)

		it("resets state after all terminals closed", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()

			termite.close_current()
			termite.close_current()

			assert.are.equal(0, #state.terminals)
			assert.are.equal(false, state.visible)
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("maintains terminal count integrity through operations", function()
			termite.create()
			termite.create()
			termite.create()

			local original_count = state.next_count
			assert.are.equal(4, original_count)

			termite.close_current()
			termite.create()

			-- next_count should continue incrementing, not reset
			assert.are.equal(5, state.next_count)
		end)
	end)

	describe("focus_editor()", function()
		it("focuses saved editor window when valid", function()
			local editor_win = vim.api.nvim_get_current_win()
			local desc = {}
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				local ok, b = pcall(vim.api.nvim_win_get_buf, w)
				local sig = "?"
				if ok then
					local jok, jid = pcall(vim.api.nvim_buf_get_var, b, "terminal_job_id")
					sig = "buf=" .. b .. " bt=" .. vim.bo[b].buftype .. " job=" .. (jok and tostring(jid) or "-")
				end
				table.insert(desc, w .. ":" .. sig)
			end
			print("DBG focus_editor wins=" .. table.concat(desc, " // "))

			termite.create()
			-- After create, we're in terminal window
			assert.are_not.equal(editor_win, vim.api.nvim_get_current_win())

			termite.focus_editor()
			assert.are.equal(editor_win, vim.api.nvim_get_current_win())
		end)

		it("focuses any non-terminal non-floating window as fallback", function()
			-- Create a new normal window as fallback
			vim.cmd("split")
			vim.cmd("q")

			termite.create()
			-- Close the original editor window
			if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
				vim.api.nvim_win_close(state.last_editor_winnr, true)
			end
			state.last_editor_winnr = nil

			termite.focus_editor()
			local current_win = vim.api.nvim_get_current_win()
			local current_buf = vim.api.nvim_win_get_buf(current_win)
			local buftype = vim.bo[current_buf].buftype

			assert.are_not.equal("terminal", buftype)
		end)
	end)

	describe("toggle() smart focus", function()
		it("hides terminals when focused on terminal", function()
			termite.create()
			termite.create()
			assert.are.equal(true, state.visible)
			assert.are.equal(2, #state.terminals)

			termite.toggle()
			assert.are.equal(false, state.visible)
		end)

		it("focuses terminals when focused on editor", function()
			termite.create()
			termite.create()

			-- Focus back to editor
			termite.focus_editor()

			-- Toggle when focused on editor should focus terminals, not hide
			termite.toggle()
			assert.are.equal(true, state.visible)
			local current_win = vim.api.nvim_get_current_win()
			local current_buf = vim.api.nvim_win_get_buf(current_win)
			assert.are.equal("terminal", vim.bo[current_buf].buftype)
		end)

		it("creates terminal when no terminals exist", function()
			assert.are.equal(0, #state.terminals)

			termite.toggle()

			assert.are.equal(1, #state.terminals)
			assert.are.equal(true, state.visible)
		end)
	end)

	describe("focus_terminals()", function()
		it("focuses the last focused terminal", function()
			termite.create()
			termite.create()
			termite.create()
			local last_idx = state.last_focused_idx
			assert.are.equal(3, last_idx)

			-- Focus editor first
			termite.focus_editor()

			termite.focus_terminals()
			local current_win = vim.api.nvim_get_current_win()
			assert.are.equal(state.terminals[last_idx].win, current_win)
		end)

		it("does nothing when no terminals visible", function()
			termite.create()
			termite.toggle() -- Hide terminals
			assert.are.equal(false, state.visible)

			local original_win = vim.api.nvim_get_current_win()
			termite.focus_terminals()
			assert.are.equal(original_win, vim.api.nvim_get_current_win())
		end)
	end)

	describe("remove_terminal()", function()
		it("removes terminal from state when buffer is wiped", function()
			termite.create()
			termite.create()
			assert.are.equal(2, #state.terminals)

			local term_to_remove = state.terminals[1]
			-- Simulate buffer wipeout (which triggers remove_terminal)
			termite.remove_terminal(term_to_remove)

			assert.are.equal(1, #state.terminals)
		end)

		it("adjusts maximized_idx when removing earlier terminal", function()
			termite.create()
			termite.create()
			termite.create()
			termite.toggle_maximize() -- Maximize terminal 3
			assert.are.equal(3, state.maximized_idx)

			-- Remove terminal 1 (earlier than maximized)
			termite.remove_terminal(state.terminals[1])

			assert.are.equal(2, state.maximized_idx) -- Adjusted down by 1
		end)
	end)

	describe("toggle_maximize()", function()
		it("restores siblings when toggling off maximize", function()
			termite.create()
			termite.create()
			termite.create()

			termite.toggle_maximize()
			assert.are.equal(3, state.maximized_idx)
			-- Only one terminal window should be valid
			local visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(1, visible_count)

			termite.toggle_maximize() -- Restore
			assert.are.equal(nil, state.maximized_idx)
			-- All terminals should be visible again
			visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(3, visible_count)
		end)
	end)

	describe("reflow()", function()
		local layout

		before_each(function()
			layout = require("termite.layout")
		end)

		local function geometry(win)
			local cfg = vim.api.nvim_win_get_config(win)
			return { width = cfg.width, height = cfg.height, row = cfg.row, col = cfg.col }
		end

		it("repairs externally changed geometry", function()
			termite.create()
			termite.create()
			local win = state.terminals[1].win
			vim.api.nvim_win_set_config(win, { width = 10, height = 5 })
			termite.reflow()
			local expected = layout.get_win_config(1, 2)
			assert.are.same(
				{ width = expected.width, height = expected.height, row = expected.row, col = expected.col },
				geometry(win)
			)
		end)

		it("re-shows externally closed windows", function()
			termite.create()
			termite.create()
			vim.api.nvim_win_close(state.terminals[2].win, true)
			termite.reflow()
			assert.is_true(vim.api.nvim_win_is_valid(state.terminals[2].win))
			local expected = layout.get_win_config(2, 2)
			assert.are.same(
				{ width = expected.width, height = expected.height, row = expected.row, col = expected.col },
				geometry(state.terminals[2].win)
			)
		end)

		it("keeps the maximized view when reflowing", function()
			termite.create()
			termite.create()
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.reflow()
			assert.are.equal(1, state.maximized_idx)
			assert.is_true(vim.api.nvim_win_is_valid(state.terminals[1].win))
		end)

		it("does nothing when hidden", function()
			termite.create()
			termite.toggle()
			assert.has_no.errors(function()
				termite.reflow()
			end)
			assert.is_false(state.visible)
		end)
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
