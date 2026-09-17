describe("tabs module", function()
	local tabs
	local state
	local config
	local highlights
	local layout

	before_each(function()
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.layout.stack"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.tabs"] = nil
		package.loaded["termite.init"] = nil
		package.loaded["termite"] = nil

		config = require("termite.config")
		state = require("termite.state")
		highlights = require("termite.highlights")
		layout = require("termite.layout")
		tabs = require("termite.tabs")

		config.setup({})
		highlights.setup()

		local editor_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(editor_buf)
	end)

	after_each(function()
		tabs.hide()
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
		state.tab_win = nil
		state.tab_buf = nil
	end)

	local function make_terminals(n)
		local terminal = require("termite.terminal")
		for _ = 1, n do
			terminal.create()
		end
		assert.are.equal(n, #state.terminals)
	end

	describe("config", function()
		it("defaults tabs to enabled on the right", function()
			assert.are.equal(true, config.values.tabs.enabled)
			assert.are.equal("right", config.values.tabs.position)
			assert.are.equal(20, config.values.tabs.max_title_width)
		end)

		it("merges partial tabs overrides", function()
			config.setup({ tabs = { position = "bottom" } })
			assert.are.equal("bottom", config.values.tabs.position)
			assert.are.equal(true, config.values.tabs.enabled)
		end)

		it("defaults tab highlight groups", function()
			assert.are.equal("TermiteTabActive", config.values.highlights.tab_active)
			assert.are.equal("TermiteTabInactive", config.values.highlights.tab_inactive)
		end)
	end)

	describe("highlights", function()
		it("defines tab highlight group names", function()
			assert.are.equal("TermiteTabActive", highlights.TAB_ACTIVE)
			assert.are.equal("TermiteTabInactive", highlights.TAB_INACTIVE)
		end)

		it("creates tab highlight groups on setup", function()
			local active = vim.api.nvim_get_hl(0, { name = "TermiteTabActive" })
			local inactive = vim.api.nvim_get_hl(0, { name = "TermiteTabInactive" })
			assert.is_not_nil(active)
			assert.is_not_nil(inactive)
		end)
	end)

	describe("should_show()", function()
		it("is false with no terminals", function()
			assert.is_false(tabs.should_show())
		end)

		it("is false when not maximized", function()
			make_terminals(2)
			assert.is_false(tabs.should_show())
		end)

		it("is false with a single maximized terminal", function()
			make_terminals(1)
			state.maximized_idx = 1
			assert.is_false(tabs.should_show())
		end)

		it("is true when maximized with multiple terminals", function()
			make_terminals(2)
			state.maximized_idx = 1
			assert.is_true(tabs.should_show())
		end)

		it("is false when tabs are disabled", function()
			config.setup({ tabs = { enabled = false } })
			make_terminals(2)
			state.maximized_idx = 1
			assert.is_false(tabs.should_show())
		end)
	end)

	describe("labels()", function()
		it("returns one indexed label per terminal", function()
			make_terminals(2)
			local labels = tabs.labels()
			assert.are.equal(2, #labels)
			assert.is_truthy(labels[1]:match("^%[1%] "))
			assert.is_truthy(labels[2]:match("^%[2%] "))
		end)
	end)

	describe("compute()", function()
		it("returns nil when tabs should not show", function()
			make_terminals(2)
			assert.is_nil(tabs.compute())
		end)

		it("computes a right-side tab rect inside the editor", function()
			make_terminals(2)
			state.maximized_idx = 1
			local info = tabs.compute()
			assert.is_not_nil(info)
			assert.are.equal("right", info.side)
			assert.is_true(info.tab.width >= 4)
			assert.is_true(info.tab.col + info.tab.width <= vim.o.columns)
			assert.are.equal(2, #info.spans)
		end)

		it("computes a bottom tab bar with one line", function()
			config.setup({ tabs = { position = "bottom" } })
			make_terminals(2)
			state.maximized_idx = 1
			local info = tabs.compute()
			assert.is_not_nil(info)
			assert.are.equal("bottom", info.side)
			assert.are.equal(1, info.tab.height)
			assert.are.equal(1, #info.lines)
		end)

		it("falls back to right for an invalid position", function()
			config.setup({ tabs = { position = "sideways" } })
			make_terminals(2)
			state.maximized_idx = 1
			local info = tabs.compute()
			assert.is_not_nil(info)
			assert.are.equal("right", info.side)
		end)
	end)

	describe("term_patch()", function()
		it("returns empty patch when tabs are hidden", function()
			make_terminals(1)
			local full = layout.get_win_config(1, 1)
			assert.are.same({}, tabs.term_patch(full))
		end)

		it("shrinks width for side tabs", function()
			make_terminals(2)
			state.maximized_idx = 1
			local full = layout.get_win_config(1, 1)
			local patch = tabs.term_patch(full)
			assert.is_true(patch.width < full.width)
			assert.is_true(patch.width >= 10)
		end)

		it("shrinks height for bottom tabs", function()
			config.setup({ tabs = { position = "bottom" } })
			make_terminals(2)
			state.maximized_idx = 1
			local full = layout.get_win_config(1, 1)
			local patch = tabs.term_patch(full)
			assert.are.equal(full.height - 1, patch.height)
		end)
	end)

	describe("update()/hide()", function()
		it("shows and hides the tab window", function()
			make_terminals(2)
			state.maximized_idx = 1
			tabs.update()
			assert.is_true(tabs.is_visible())
			local buf = state.tab_buf
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			assert.is_true(#vim.api.nvim_buf_get_lines(buf, 0, -1, false) >= 2)
			tabs.hide()
			assert.is_false(tabs.is_visible())
		end)

		it("hides when tabs should not show", function()
			make_terminals(2)
			state.maximized_idx = 1
			tabs.update()
			assert.is_true(tabs.is_visible())
			state.maximized_idx = nil
			tabs.update()
			assert.is_false(tabs.is_visible())
		end)
	end)

	describe("resolve_index()", function()
		it("maps vertical rows to terminal indices", function()
			assert.are.equal(1, tabs.resolve_index(true, 1, 0, 3))
			assert.are.equal(3, tabs.resolve_index(true, 3, 0, 3))
			assert.is_nil(tabs.resolve_index(true, 4, 0, 3))
			assert.is_nil(tabs.resolve_index(true, 0, 0, 3))
		end)

		it("maps horizontal columns through rendered spans", function()
			config.setup({ tabs = { position = "bottom" } })
			make_terminals(2)
			state.maximized_idx = 1
			tabs.update()
			assert.are.equal(1, tabs.resolve_index(false, 1, 1, 2))
			assert.is_nil(tabs.resolve_index(false, 1, 10000, 2))
		end)
	end)

	describe("maximized switching", function()
		local termite

		before_each(function()
			termite = require("termite")
		end)

		local function visible_border_chars(win)
			local cfg = vim.api.nvim_win_get_config(win)
			local chars = {}
			for _, part in ipairs(cfg.border) do
				local char = type(part) == "table" and part[1] or part
				if char ~= "" and char ~= " " then
					table.insert(chars, char)
				end
			end
			return chars
		end

		it("cycles the maximized view with focus_next", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			assert.are.equal(1, state.maximized_idx)
			assert.is_true(tabs.is_visible())
			termite.focus_next()
			assert.are.equal(2, state.maximized_idx)
			assert.are.equal(state.terminals[2].win, vim.api.nvim_get_current_win())
			assert.is_true(tabs.is_visible())
		end)

		it("jumps to a tab with focus_index", function()
			make_terminals(3)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.focus_index(3)
			assert.are.equal(3, state.maximized_idx)
			assert.are.equal(state.terminals[3].win, vim.api.nvim_get_current_win())
		end)

		it("moves the tab highlight when jumping while maximized", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[2].win)
			termite.toggle_maximize()
			termite.focus_index(1)
			assert.are.equal(1, state.maximized_idx)

			local ns = vim.api.nvim_get_namespaces()["termite_tabs"]
			local marks = vim.api.nvim_buf_get_extmarks(state.tab_buf, ns, 0, -1, { details = true })
			local row_hl = {}
			for _, mark in ipairs(marks) do
				row_hl[mark[2]] = mark[4].hl_group
			end
			assert.are.equal("TermiteTabActive", row_hl[0])
			assert.are.equal("TermiteTabInactive", row_hl[1])
		end)

		it("renders tabs with custom highlight groups", function()
			config.setup({ highlights = { tab_active = "Keyword", tab_inactive = "Comment" } })
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()

			local ns = vim.api.nvim_get_namespaces()["termite_tabs"]
			local marks = vim.api.nvim_buf_get_extmarks(state.tab_buf, ns, 0, -1, { details = true })
			local row_hl = {}
			for _, mark in ipairs(marks) do
				row_hl[mark[2]] = mark[4].hl_group
			end
			assert.are.equal("Keyword", row_hl[0])
			assert.are.equal("Comment", row_hl[1])
		end)

		it("stays maximized when the maximized terminal is closed", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.close_current()
			assert.are.equal(1, #state.terminals)
			assert.are.equal(1, state.maximized_idx)
			assert.is_false(tabs.is_visible())
		end)

		it("restores and hides tabs on toggle_maximize twice", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			assert.is_true(tabs.is_visible())
			termite.toggle_maximize()
			assert.is_nil(state.maximized_idx)
			assert.is_false(tabs.is_visible())
		end)

		it("shows only the outer-edge border on the maximized terminal", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			assert.are.same({ "│" }, visible_border_chars(state.terminals[1].win))
		end)

		it("keeps only the outer-edge border across focus changes", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.focus_editor()
			termite.focus_terminals()
			assert.are.same({ "│" }, visible_border_chars(state.terminals[1].win))
		end)

		it("restores separator borders when un-maximizing", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.toggle_maximize()
			local chars = visible_border_chars(state.terminals[1].win)
			assert.is_true(#chars > 0)
		end)

		it("appends a tab and stays maximized when creating", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.create()
			assert.are.equal(3, #state.terminals)
			assert.are.equal(3, state.maximized_idx)
			assert.are.equal(state.terminals[3].win, vim.api.nvim_get_current_win())
			assert.is_true(tabs.is_visible())
			assert.are.equal(3, #tabs.labels())
			local visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(1, visible_count)
		end)

		it("remembers the maximized view across toggle", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.toggle()
			assert.are.equal(false, state.visible)

			termite.toggle()
			assert.are.equal(true, state.visible)
			assert.are.equal(1, state.maximized_idx)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
			assert.is_true(tabs.is_visible())
			local visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(1, visible_count)
		end)

		it("forgets the maximized view on explicit restore", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.toggle_maximize()
			termite.toggle()
			termite.toggle()
			assert.is_nil(state.maximized_idx)
			local visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(2, visible_count)
		end)

		it("shows split view when creating while hidden", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.toggle()
			termite.create()
			assert.is_nil(state.maximized_idx)
			assert.are.equal(3, #state.terminals)
			local visible_count = 0
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					visible_count = visible_count + 1
				end
			end
			assert.are.equal(3, visible_count)
		end)

		it("keeps remembered maximized valid after hidden removal", function()
			make_terminals(2)
			vim.api.nvim_set_current_win(state.terminals[1].win)
			termite.toggle_maximize()
			termite.toggle()
			termite.remove_terminal(state.terminals[2])
			termite.toggle()
			assert.are.equal(1, state.maximized_idx)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
