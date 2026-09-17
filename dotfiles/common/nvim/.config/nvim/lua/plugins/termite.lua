return {
  "ruicsh/termite.nvim",
  dir = "~/.config/nvim/lua/plugins/termite.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    position = "bottom",
    height = 0.4,
    tabs = {
      position = "right", -- tab bar side: "top", "right", "bottom", or "left"
    },
  },
  keys = {
    { "<C-/>", "<cmd>Termite toggle<cr>", mode = { "n", "t" }, desc = "Toggle Terminal" },
    { "<C-_>", "<cmd>Termite toggle<cr>", mode = { "n", "t" }, desc = "Toggle Terminal" },
    { "<C-t>", "<cmd>Termite create<cr>", mode = { "n", "t" }, desc = "Create Terminal" },
    { "<C-n>", "<cmd>Termite next<cr>", mode = { "n", "t" }, desc = "Next Terminal" },
    { "<C-b>", "<cmd>Termite prev<cr>", mode = { "n", "t" }, desc = "Previous Terminal" },

    { "<A-1>", "<cmd>Termite goto 1<cr>", mode = { "n", "t" }, desc = "Jump to Term 1" },
    { "<A-2>", "<cmd>Termite goto 2<cr>", mode = { "n", "t" }, desc = "Jump to Term 2" },
    { "<A-3>", "<cmd>Termite goto 3<cr>", mode = { "n", "t" }, desc = "Jump to Term 3" },
    { "<A-4>", "<cmd>Termite goto 4<cr>", mode = { "n", "t" }, desc = "Jump to Term 4" },
    { "<A-5>", "<cmd>Termite goto 5<cr>", mode = { "n", "t" }, desc = "Jump to Term 5" },
  },
  config = function(_, opts)
    require("termite").setup(opts)

    local function apply_colors()
      -- Title text stays orange/accent with no background block
      vim.api.nvim_set_hl(0, "TermiteWinbar", { link = "Keyword", bg = "NONE", default = false })
      vim.api.nvim_set_hl(0, "WinBar", { bg = "NONE", default = false })
      vim.api.nvim_set_hl(0, "WinBarNC", { bg = "NONE", default = false })

      vim.api.nvim_set_hl(0, "TermiteTabActive", { link = "Keyword", bg = "NONE", default = false })
      -- Link all terminal borders directly to default WinSeparator
      vim.api.nvim_set_hl(0, "TermiteBorder", { link = "WinSeparator", default = false })
      vim.api.nvim_set_hl(0, "TermiteBorderSingle", { link = "WinSeparator", default = false })
      vim.api.nvim_set_hl(0, "TermiteBorderNC", { link = "WinSeparator", default = false })
    end

    apply_colors()

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("TermiteColorFix", { clear = true }),
      callback = apply_colors,
    })
  end,
}
