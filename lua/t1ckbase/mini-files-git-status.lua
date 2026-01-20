---@class MiniFilesGitStatus.Config
---@field display_mode? 'sign_text'|'virt_text' How to display git status
---@field virt_text_pos? 'eol'|'eol_right_align'|'inline'|'overlay'|'right_align' Position for virtual text (when display_mode is 'virt_text')
---@field precache_depth? integer Depth of subdirectories to precache (default: 2, means current + 1 level)
---@field status_map? table<string, {icon: string, hl: string}> Mapping from git XY status to icon and highlight
---@field default_highlight? string Default highlight group for git status

local M = {}

-- Default configuration
M.config = {
  display_mode = 'sign_text',
  virt_text_pos = 'right_align',
  precache_depth = 2,
  status_map = {
    -- ['--'] = { icon = '' },
  },
  default_highlight = 'MiniFilesFile',
}

-- Namespace for extmarks
local NS = vim.api.nvim_create_namespace('mini_files_git_status')

local EZA_PATTERN = [[^(%S+)%s+['"]?(.-)['"]?$]]
local DIR_HEADER_PATTERN = [[^%.?[/\\]?(.-):%s*$]]

local cache = {}

-- Parse eza recursive output and update cache
-- Format: lines are either "STATUS filename" or "path:" (directory header)
---@param output string
---@param base_path string Base path for resolving relative paths
local function update_cache(output, base_path)
  local current_dir = base_path
  for line in output:gmatch('[^\r\n]+') do
    -- Check if this is a directory header (e.g., ".\lua:" or "./subdir:")
    local dir_match = line:match(DIR_HEADER_PATTERN)
    if dir_match then
      if dir_match == '' or dir_match == '.' then
        current_dir = base_path
      else
        current_dir = vim.fs.normalize(vim.fs.joinpath(base_path, dir_match))
      end
    else
      -- Parse file entry
      local git_status, filename = line:match(EZA_PATTERN)
      if git_status and filename then
        if not cache[current_dir] then
          cache[current_dir] = {}
        end
        cache[current_dir][filename] = git_status
      end
    end
  end
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
  if not vim.api.nvim_buf_is_valid(buf_id) or not status_map then
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

--- Update git status cache for a path
---@param path string Absolute path to update cache for
---@param callback? fun() Optional callback when caching is complete
function M.update_cache(path, callback)
  local normalized_path = vim.fs.normalize(path)
  local depth = math.max(M.config.precache_depth or 1, 1)

  vim.system(
    {
      'eza',
      '--long',
      '--recurse',
      '--color=never',
      '--icons=never',
      '--all',
      '--level=' .. depth,
      '--git',
      '--no-permissions',
      '--no-filesize',
      '--no-user',
      '--no-time',
      '.',
    },
    { text = true, cwd = normalized_path },
    vim.schedule_wrap(function(obj)
      if obj.code == 0 then
        update_cache(obj.stdout, normalized_path)
        if callback then
          callback()
        end
      else
        vim.notify('(mini.files-git-status) eza failed: ' .. obj.stderr, vim.log.levels.ERROR)
      end
    end)
  )
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
      local stat = vim.uv.fs_stat(path)

      if not stat or stat.type ~= 'directory' then
        return
      end

      update_extmarks(buf_id, cache[path])

      M.update_cache(path, function()
        update_extmarks(buf_id, cache[path])
      end)
    end,
  })
end

--- Clear git status cache
---@param path? string Optional path to clear, clears all if not provided
function M.clear_cache(path)
  if path then
    cache[vim.fs.normalize(path)] = nil
  else
    cache = {}
  end
end

return M
