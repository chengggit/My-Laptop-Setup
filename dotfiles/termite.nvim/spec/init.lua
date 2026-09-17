-- Bootstrap init for running tests in CI
-- Adds plenary.nvim and plugin to runtimepath

local test_root = vim.fn.getcwd()
vim.opt.rtp:prepend(test_root)

-- Add plenary.nvim (cloned by CI to vendor/plenary.nvim)
local plenary_path = test_root .. "/vendor/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.rtp:prepend(plenary_path)
end

-- Load plenary's plugin file to make PlenaryBustedDirectory available
vim.cmd.runtime({ "plugin/plenary.vim", bang = true })

if vim.env.TERMITE_TRACE_OPENS then
	local _probe = io.open("/tmp/opencode/harness_probe.txt", "a")
	if _probe then
		_probe:write("harness loaded\n")
		_probe:close()
	end
	local orig_open = vim.api.nvim_open_win
	vim.api.nvim_open_win = function(buf, enter, config)
		local f = io.open("/tmp/opencode/opens.log", "a")
		if f then
			f:write(string.format(
				"OPEN buf=%d bt=%s z=%s bore=%s\n  %s\n",
				buf,
				vim.bo[buf].buftype,
				tostring(config.zindex),
				type(config.border) == "string" and config.border or "array",
				debug.traceback("", 2):gsub("\n", " <- "):sub(1, 500)
			))
			f:close()
		end
		return orig_open(buf, enter, config)
	end
end
