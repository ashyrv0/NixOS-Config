-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.spell = true
vim.opt.spelllang = "en"

vim.g.mapleader = " "

-- Colorscheme
require("tokyonight").setup({
  style = "night",
  transparent = false,
  terminal_colors = true,
})
vim.cmd[[colorscheme tokyonight]]

-- Nvim Tree
require("nvim-tree").setup()
vim.keymap.set("n", "<leader>\\", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- Lualine
require("lualine").setup({
  options = {
    theme = "tokyonight",
    component_separators = "",
    section_separators = { left = "", right = "" },
    globalstatus = true,
  },
})

-- Telescope
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags,  { desc = "Telescope help tags" })

-- Alpha dashboard
local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

dashboard.section.header.val = {
  "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██║   ██║██║████╗ ████║",
  "██╔██╗ ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

dashboard.section.buttons.val = {
  dashboard.button("e", "  󰈔 New file",     ":ene <BAR> startinsert <CR>"),
  dashboard.button("r", "  󱁚 Recent files", ":Telescope oldfiles<CR>"),
  dashboard.button("t", "  󰈞 Find file",    ":Telescope find_files<CR>"),
  dashboard.button("q", "  󰅖 Quit",         ":qa<CR>"),
}

dashboard.config.layout = {
  { type = "padding", val = vim.fn.max { 2, vim.fn.floor(vim.fn.winheight(0) * 0.2) } },
  dashboard.section.header,
  { type = "padding", val = 5 },
  dashboard.section.buttons,
  { type = "padding", val = 3 },
  dashboard.section.footer,
}

alpha.setup(dashboard.config)