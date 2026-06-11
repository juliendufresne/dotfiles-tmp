return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "<leader>e", ":NvimTreeToggle<CR>", desc = "Toggle File Explorer" },
    },
    config = function()
        require("nvim-tree").setup()
    end,
}
