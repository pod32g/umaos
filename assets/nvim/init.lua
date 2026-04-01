-- UmaOS NeoVim Configuration
-- Curated defaults for development

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.clipboard = "unnamedplus"
vim.opt.scrolloff = 8
vim.opt.mouse = "a"

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- UmaOS color scheme (matching UmaGreenPink palette)
vim.cmd([[
  highlight Normal guibg=#0e1f14 guifg=#F8FBFF
  highlight CursorLine guibg=#12301a
  highlight Visual guibg=#42a54b guifg=#F8FBFF
  highlight StatusLine guibg=#42a54b guifg=#F8FBFF
  highlight StatusLineNC guibg=#12301a guifg=#F8FBFF
  highlight LineNr guifg=#4A6A8A
  highlight CursorLineNr guifg=#FF91C0
  highlight Comment guifg=#4A6A8A gui=italic
  highlight String guifg=#82C91E
  highlight Keyword guifg=#FF91C0
  highlight Function guifg=#42a54b
  highlight Type guifg=#FFD6E8
  highlight Constant guifg=#FFC66D
  highlight Pmenu guibg=#12301a guifg=#F8FBFF
  highlight PmenuSel guibg=#42a54b guifg=#F8FBFF
  highlight Search guibg=#FF91C0 guifg=#0e1f14
]])

-- Key mappings
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search" })
