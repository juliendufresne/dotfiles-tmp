return {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>f", function() require("telescope.builtin").find_files() end, desc = "Find Files" },
        { "<leader>g", function() require("telescope.builtin").git_files() end, desc = "Git Files" },
        { "<leader>b", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
    },
    config = function()
        require("telescope").setup({
            defaults = { sorting_strategy = "ascending" },
        })
    end,
}
