---@class MiniFilesGitStatus.Config
---@field display_mode? 'sign_text'|'virt_text' How to display git status
---@field virt_text_pos? 'eol'|'eol_right_align'|'inline'|'overlay'|'right_align' Position for virtual text (when display_mode is 'virt_text')
---@field status_map? table<string, {icon: string, hl: string}> Mapping from git XY status to icon and highlight
---@field default_highlight? string Default highlight group for git status

local M = {}

-- Default configuration
M.config = {
  display_mode = 'sign_text',
  virt_text_pos = 'right_align',
  status_map = {
    -- ['--'] = { icon = '' },
  },
  default_highlight = 'MiniFilesFile',
}

-- Namespace for extmarks
local NS = vim.api.nvim_create_namespace('mini_files_git_status')

local EZA_PATTERN = [[^(%S+)%s+['"]?(.-)['"]?$]]

local cache = {}

-- Parse eza output
---@param output string
---@return table<string, string> Map of file names to git status
local function parse_eza_output(output)
  local status_map = {}
  for line in output:gmatch('[^\r\n]+') do
    local git_status, filename = line:match(EZA_PATTERN)
    if git_status and filename then
      status_map[filename] = git_status
    end
  end
  return status_map
end

-- Map git status to display info
---@param status string
---@return string|nil icon, string|nil hl_group
local function map_status(status)
  local mapped = M.config.status_map[status] or {}
  return mapped.icon or status, mapped.hl or M.config.default_highlight
end

-- Update git status extmarks in a buffer
---@param buf_id integer
---@param status_map table<string, string>
local function update_extmarks(buf_id, status_map)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

  local nlines = vim.api.nvim_buf_line_count(buf_id)

  for line_num = 0, nlines - 1 do
    local entry = MiniFiles.get_fs_entry(buf_id, line_num + 1)
    if not entry then
      break
    end

    local status = status_map[entry.name]
    if status then
      local icon, hl_group = map_status(status)
      if icon and icon ~= '' and hl_group then
        local extmark_opts = { priority = 2 }

        if M.config.display_mode == 'sign_text' then
          extmark_opts.sign_text = icon
          extmark_opts.sign_hl_group = hl_group
        elseif M.config.display_mode == 'virt_text' then
          extmark_opts.virt_text = { { icon, hl_group } }
          extmark_opts.virt_text_pos = M.config.virt_text_pos
        end

        vim.api.nvim_buf_set_extmark(buf_id, NS, line_num, 0, extmark_opts)
      end
    end
  end
end

-- Setup the plugin
---@param user_config MiniFilesGitStatus.Config?
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

  if vim.fn.executable('eza') == 0 then
    vim.notify('(mini.files-git-status) eza not found', vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('mini_files_git_status', { clear = true }),
    pattern = 'MiniFilesBufferUpdate',
    callback = function(args)
      local buf_id = args.data.buf_id

      local path = vim.api.nvim_buf_get_name(buf_id):gsub('^minifiles://%d+/', '')

      if cache[path] then
        update_extmarks(buf_id, cache[path])
      end

      vim.system(
        { 'eza', '--long', '--color=never', '--icons=never', '--all', '--git', '--no-permissions', '--no-filesize', '--no-user', '--no-time', path },
        { text = true },
        vim.schedule_wrap(function(obj)
          if obj.code == 0 then
            local status_map = parse_eza_output(obj.stdout)
            cache[path] = status_map
            update_extmarks(buf_id, status_map)
          else
            vim.notify('(mini.files-git-status) eza failed: ' .. obj.stderr, vim.log.levels.ERROR)
          end
        end)
      )
    end,
  })
end

--- Clear git status cache
---@param path? string Optional path to clear, clears all if not provided
function M.clear_cache(path)
  if path then
    cache[path] = nil
  else
    cache = {}
  end
end

return M
