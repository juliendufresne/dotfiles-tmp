return {
    "neovim/nvim-lspconfig",

    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "williamboman/mason-lspconfig.nvim",
    },

    config = function()
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        vim.diagnostic.config({
            virtual_text = true,
            signs = true,
            underline = true,
            severity_sort = true,
        })

        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local bufnr = args.buf
                local map = function(mode, lhs, rhs)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
                end

                map("n", "gd", vim.lsp.buf.definition)
                map("n", "gr", vim.lsp.buf.references)
                map("n", "K", vim.lsp.buf.hover)
                map("n", "<leader>rn", vim.lsp.buf.rename)
                map("n", "<leader>ca", vim.lsp.buf.code_action)
            end,
        })

        -- Safe server registry
        local servers = {
            bashls = {},
            marksman = {},
            yamlls = {},

            pyright = {},
            ts_ls = {},
            terraformls = {},

            intelephense = {
                settings = {
                    intelephense = {
                        files = {
                            maxSize = 5000000,
                        },
                    },
                },
            },
        }

        -- Optional: only enable if available in runtime
        for name, config in pairs(servers) do
            vim.lsp.config(name, vim.tbl_extend("force", {
                capabilities = capabilities,
            }, config))
        end

        -- SAFE enable:
        -- Only enables installed/available servers
        vim.lsp.enable(vim.tbl_keys(servers))
    end,
}
