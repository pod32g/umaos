-- UmaOS NvChad theme — green turf / pink silks palette

local M = {}

M.base_30 = {
  white = "#dce8de",
  darker_black = "#0a1610",
  black = "#0e1f14", -- nvim bg
  black2 = "#162b1c",
  one_bg = "#1e3726",
  one_bg2 = "#264430",
  one_bg3 = "#2e5038",
  grey = "#4a6a52",
  grey_fg = "#5a7a62",
  grey_fg2 = "#6a8a72",
  light_grey = "#80b088",
  red = "#ff7c8a",
  baby_pink = "#ffaad0",
  pink = "#ff91c0",
  line = "#1e3726",
  green = "#42a54b",
  vibrant_green = "#82e08c",
  nord_blue = "#5a9ee6",
  blue = "#788ce6",
  yellow = "#ffdc8c",
  sun = "#f0c864",
  purple = "#c8aaf0",
  dark_purple = "#d278b4",
  teal = "#64d7d7",
  orange = "#e8a060",
  cyan = "#82f5f5",
  statusline_bg = "#162b1c",
  lightbg = "#1e3726",
  pmenu_bg = "#42a54b",
  folder_bg = "#42a54b",
}

M.base_16 = {
  base00 = "#0e1f14",
  base01 = "#162b1c",
  base02 = "#1e3726",
  base03 = "#4a6a52",
  base04 = "#6a8a72",
  base05 = "#dce8de",
  base06 = "#e8f0ea",
  base07 = "#f0f8f2",
  base08 = "#ff7c8a",
  base09 = "#e8a060",
  base0A = "#ffdc8c",
  base0B = "#42a54b",
  base0C = "#64d7d7",
  base0D = "#788ce6",
  base0E = "#c8aaf0",
  base0F = "#d278b4",
}

M.type = "dark"

M = require("base46").override_theme(M, "umaos")

return M
