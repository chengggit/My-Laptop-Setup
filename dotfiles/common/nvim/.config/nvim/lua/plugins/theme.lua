return {
  -- 1. Install the Everforest plugin
  {
    "neanias/everforest-nvim",
    lazy = false,
    priority = 1000, -- Ensure it loads before all other plugins
    config = function()
      require("everforest").setup({
        background = "hard",
        colours_override = function(palette)
          palette.bg0 = "#1e2326"
        end,
      })
    end,
  },
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
    config = function()
      require("ayu").colorscheme({
        mirage = true,
      })
    end,
  },
  -- 2. Tell LazyVim to actively use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ayu",
    },
  },
}
