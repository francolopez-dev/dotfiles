-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.keymap.set("n", "<leader>l", "<Cmd>bnext<CR>", { silent = true })
vim.keymap.set("n", "<leader>h", "<Cmd>bprevious<CR>", { silent = true })
