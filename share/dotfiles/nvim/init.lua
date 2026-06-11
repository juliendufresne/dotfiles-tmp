-- General settings (loaded first so the editor options apply even when the
-- plugin layer is unavailable, e.g. a fresh offline start with no plugins).
require("config.settings")

-- Keymaps
require("config.keybindings")

-- Plugins (best-effort: a missing network or an absent lazy.nvim must never
-- abort startup, so the bootstrap is wrapped and degrades to a plugin-less
-- but fully usable editor).
pcall(require, "config.lazy")
