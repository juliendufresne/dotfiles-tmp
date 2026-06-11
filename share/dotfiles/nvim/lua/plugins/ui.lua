return {
    {
        "nvim-lualine/lualine.nvim",
        config = function()
            require("lualine").setup()
        end,
    },

    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup()
        end,
    },
}
