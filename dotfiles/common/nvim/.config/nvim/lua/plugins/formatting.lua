return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- This seamlessly injects 'rics' right next to lua, fish, and sh in the core config
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.scss = opts.formatters_by_ft.scss or { "prettier" }
    end,
  },
}
