-- ftdetect/drools.lua
-- Register .drl and .dsl file extensions for drools filetype

if vim.filetype then
  vim.filetype.add({
    extension = {
      drl = "drools",
      dsl = "drools",
    },
  })
else
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.drl", "*.dsl" },
    callback = function()
      vim.bo.filetype = "drools"
    end,
  })
end
