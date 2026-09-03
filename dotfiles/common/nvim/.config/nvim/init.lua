-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local function insert_block_comment()
  -- Fetch the comment string for the current file type
  local comment_string = vim.bo.commentstring

  -- Fallback to C-style /* %s */ if no comment string is set
  if comment_string == "" then
    comment_string = "/* %s */"
  end

  -- Split the comment string at the '%s' placeholder
  local parts = {}
  for part in string.gmatch(comment_string, "([^%%s]+)") do
    table.insert(parts, part)
  end

  local left_marker = parts[1] or "/* "
  local right_marker = parts[2] or " */"

  -- If the language default is single-line (e.g. "// %s"), convert to block style
  if not parts[2] then
    if left_marker:match("//") then
      left_marker = "/* "
      right_marker = " */"
    elseif left_marker:match("#") then
      left_marker = " <!-- "
      right_marker = " --> "
    elseif left_marker:match("%-%-") then
      left_marker = "--[[ "
      right_marker = " ]]"
    end
  end

  -- Insert the complete block at cursor position
  vim.api.nvim_put({ left_marker .. right_marker }, "c", true, true)

  -- Calculate how far back to move the cursor to land in the center
  local move_back = vim.api.nvim_strwidth(right_marker)

  -- Move cursor to the middle and start insert mode
  vim.cmd("normal! " .. move_back .. "h")
  vim.cmd("startinsert")
end

-- 1. Map for Normal Mode
vim.keymap.set("n", "<C-S-a>", insert_block_comment, { desc = "Insert block comment at cursor" })

-- 2. Map for Insert Mode
vim.keymap.set("i", "<C-S-a>", function()
  -- Exit insert mode briefly, run the logic, and let the function re-trigger insert mode
  vim.cmd("stopinsert")
  insert_block_comment()
end, { desc = "Insert block comment at cursor from Insert mode" })
