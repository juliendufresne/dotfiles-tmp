return {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
        ensure_installed = {
            "bashls",
            "marksman",
            "yamlls",
        },
        automatic_installation = true,
    },
}
