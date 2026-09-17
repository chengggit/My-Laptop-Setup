return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        hidden = true,
        ignored = true,
      },
      terminal = {
        enabled = false,
      },
    },
    keys = {
      { "<c-/>", false, mode = { "n", "t" } },
      { "<c-_>", false, mode = { "n", "t" } },
    },
  },
}
