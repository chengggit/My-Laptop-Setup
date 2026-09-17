return {
  {
    "nvzone/minty",
    dependencies = { "nvzone/volt" },
    cmd = { "Shades", "Huefy" },
  },
  {
    "brenoprata10/nvim-highlight-colors",
    event = "BufReadPre",
    opts = {
      render = "virtual",
      virtual_symbol = "■",
      enable_named_colors = true,
      enable_tailwinds = true,
    },
  },
}
