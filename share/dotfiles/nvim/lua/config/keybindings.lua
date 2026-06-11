local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h")
map("n", "<C-l>", "<C-w>l")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")

-- Clear search
map("n", "<leader>h", ":nohlsearch<CR>")

-- Save & quit
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")

-- Escape
map("i", "jk", "<Esc>")

-- Move lines
map("n", "<A-j>", ":m .+1<CR>==")
map("n", "<A-k>", ":m .-2<CR>==")
