-- lua/telescope/_extensions/drools.lua
-- Telescope extension for searching Drools rules, declarations, and symbols

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  return nil
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local nav = require("drools.navigation")

local function rules_picker(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local symbols = nav.get_symbols(bufnr)

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 10 },
      { remaining = true },
    },
  })

  local function make_display(entry)
    return displayer({
      { "[" .. entry.type:upper() .. "]", "TelescopeResultsNumber" },
      entry.name,
    })
  end

  pickers.new(opts, {
    prompt_title = "Drools Symbols",
    finder = finders.new_table({
      results = symbols,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = entry.name .. " " .. entry.type,
          name = entry.name,
          type = entry.type,
          lnum = entry.lnum,
          filename = vim.api.nvim_buf_get_name(bufnr),
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.vim_buffer_cat.new(opts),
  }):find()
end

return telescope.register_extension({
  exports = {
    drools = rules_picker,
    symbols = rules_picker,
    rules = rules_picker,
  },
})
