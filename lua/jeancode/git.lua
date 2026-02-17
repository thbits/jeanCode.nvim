local M = {}

--- Get the git root for a given path, or the current buffer's file.
--- Falls back to the file's directory if not in a git repo.
function M.get_root(path)
  path = path or vim.api.nvim_buf_get_name(0)
  local dir
  if path ~= "" then
    dir = vim.fn.fnamemodify(path, ":h")
  else
    dir = vim.fn.getcwd()
  end

  local result = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")
  if vim.v.shell_error == 0 and result[1] then
    return result[1]
  end
  -- Not in a git repo - return the file's directory
  return dir
end

return M
