vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Hermetic gate: when DOTFILES_SKIP_NVIM_PLUGINS is set the bootstrap is
-- skipped entirely (no network clone), mirroring the installer's own skip so a
-- headless config read in CI never reaches GitHub. The editor still loads with
-- settings and keybindings only.
local skip_plugins = (vim.env.DOTFILES_SKIP_NVIM_PLUGINS or "") ~= ""

if not skip_plugins and not vim.loop.fs_stat(lazypath) then
    -- Best-effort clone: offline this fails, and the guard below then degrades
    -- to a plugin-less start rather than letting the error abort startup.
    pcall(function()
        vim.fn.system({
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            lazypath,
        })
    end)
end

if skip_plugins then
    return
end

-- lazy.nvim still absent (offline, or the clone was skipped): stop here so the
-- editor stays usable with settings and keybindings only.
if not vim.loop.fs_stat(lazypath) then
    return
end

vim.opt.rtp:prepend(lazypath)

local ok, lazy = pcall(require, "lazy")
if not ok then
    return
end

lazy.setup("plugins", {
    defaults = { lazy = true },
    checker = { enabled = true, notify = false },
    change_detection = { enabled = false },
    install = { missing = true },
    -- Keep the lockfile out of the config dir: that dir is the dotfiles symlink
    -- (read-only in CI), so a headless `Lazy! sync` must not write back into it.
    -- stdpath('data') is writable and is the tree the uninstall removes.
    lockfile = vim.fn.stdpath("data") .. "/lazy/lazy-lock.json",
    ui = {                                         -- completely disable dashboard UI
        show = { header = false, cmdline = false, tabline = false, border = false },
        border = "none",
    },
})
