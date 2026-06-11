return {
    "ellisonleao/gruvbox.nvim",
    lazy = false,         -- load on startup
    priority = 1000,      -- ensure loaded before other plugins
    config = function()
        -- Set Gruvbox options (replaces require("gruvbox").setup())
        vim.g.gruvbox_contrast_dark = "medium"

        -- Set dark background and apply colorscheme
        vim.o.background = "dark"
        -- Tolerant apply: a fresh, plugin-less start has no colorscheme yet, so
        -- never let a missing gruvbox abort startup.
        pcall(vim.cmd, "colorscheme gruvbox")

        -- Optional: transparent background
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
        vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
    end,
}
