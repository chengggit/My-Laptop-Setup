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

  -- 2. Tell LazyVim to actively use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
