-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Easier line boundaries
vim.keymap.set({ "n", "v" }, "-", "$", { desc = "Go to end of line" })

-- App-like save and search
vim.keymap.set({ "n", "i", "v" }, "<D-s>", "<Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<D-f>", "/", { desc = "Search in file" })
vim.keymap.set("i", "<D-f>", "<Esc>/", { desc = "Search in file" })

-- App-like comment toggles using LazyVim's default comment mappings
vim.keymap.set("n", "<C-/>", "gcc", { desc = "Toggle comment", remap = true })
vim.keymap.set("v", "<C-/>", "gc", { desc = "Toggle comment", remap = true })
vim.keymap.set("n", "<C-_>", "gcc", { desc = "Toggle comment", remap = true })
vim.keymap.set("v", "<C-_>", "gc", { desc = "Toggle comment", remap = true })
vim.keymap.set("n", "<D-/>", "gcc", { desc = "Toggle comment", remap = true })
vim.keymap.set("v", "<D-/>", "gc", { desc = "Toggle comment", remap = true })

-- Move lines up/down
vim.keymap.set("n", "<A-Down>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-Up>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("i", "<A-Down>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down" })
vim.keymap.set("i", "<A-Up>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Duplicate lines/selections up/down
vim.keymap.set("n", "<A-S-Down>", "yyp", { desc = "Duplicate line down" })
vim.keymap.set("n", "<A-S-Up>", "yyP", { desc = "Duplicate line up" })
vim.keymap.set("v", "<A-S-Down>", ":t'><CR>gv", { desc = "Duplicate selection down" })
vim.keymap.set("v", "<A-S-Up>", ":t'<-1<CR>gv", { desc = "Duplicate selection up" })

-- Reliable Alt+h/j/k/l alternatives for terminals that don't pass Alt+arrows cleanly
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Word movement
vim.keymap.set({ "n", "v" }, "<A-Left>", "b", { desc = "Move word left" })
vim.keymap.set({ "n", "v" }, "<A-Right>", "w", { desc = "Move word right" })
vim.keymap.set("i", "<A-Left>", "<C-o>b", { desc = "Move word left" })
vim.keymap.set("i", "<A-Right>", "<C-o>w", { desc = "Move word right" })

vim.keymap.set({ "n", "v" }, "<A-h>", "b", { desc = "Move word left" })
vim.keymap.set({ "n", "v" }, "<A-l>", "w", { desc = "Move word right" })
vim.keymap.set("i", "<A-h>", "<C-o>b", { desc = "Move word left" })
vim.keymap.set("i", "<A-l>", "<C-o>w", { desc = "Move word right" })

-- Terminal-like word deletion in insert mode
vim.keymap.set("i", "<A-d>", "<C-o>dw", { desc = "Delete next word" })
vim.keymap.set("i", "<A-BS>", "<C-w>", { desc = "Delete previous word" })
