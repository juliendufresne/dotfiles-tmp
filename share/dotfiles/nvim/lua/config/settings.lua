local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true

-- Scrolling
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Files
opt.hidden = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- Performance
opt.updatetime = 300

-- Colors
opt.termguicolors = true

-- Leader
vim.g.mapleader = " "
