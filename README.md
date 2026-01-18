<!--
TODO:
Add statuscolumn example
Add neo-tree.nvim icons config example
Add nvim-tree.lua icons config example
Add vimdoc
-->

# mini-files-git-status

A simple Neovim plugin to display git status in mini.files.

## Features

- Display git status icons in mini.files using extmarks (signs or virtual text)

<!-- TODO: Add screenshots -->

## Requirements

- Neovim 0.11.0+
- [mini.nvim](https://github.com/nvim-mini/mini.nvim) with `mini.files` or [mini.files](https://github.com/nvim-mini/mini.files)
- [eza](https://github.com/eza-community/eza)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  't1ckbase/mini-files-git-status',
  dependencies = { 'nvim-mini/mini.nvim' }, -- or 'nvim-mini/mini.files'
  config = function()
    require('t1ckbase.mini-files-git-status').setup()
  end,
}
```

### [mini.deps](https://github.com/nvim-mini/mini.deps)

```lua
local add, later = MiniDeps.add, MiniDeps.later

later(function()
  add({
    source = 't1ckbase/mini-files-git-status',
    depends = { 'nvim-mini/mini.nvim' }, -- or 'nvim-mini/mini.files'
  })

  require('t1ckbase.mini-files-git-status').setup()
end)
```

## Configuration

> [!TIP]
> **Eza Git Status Reference**
>
> | Status | Description  |
> | ------ | ------------ |
> | `-`    | Not modified |
> | `N`    | New          |
> | `M`    | Modified     |
> | `D`    | Deleted      |
> | `R`    | Renamed      |
> | `T`    | Type change  |
> | `I`    | Ignored      |
> | `U`    | Conflicted   |
>
> <sub>[eza source](https://github.com/eza-community/eza/blob/58b98cfa542fdd6ac5bba8fb13f077e9f6fd1f5b/src/output/render/git.rs#L25-L32)</sub>

Default config:

```lua
{
  -- Display mode: 'sign_text' or 'virt_text'
  display_mode = 'sign_text',

  -- Position for virtual text (when display_mode is 'virt_text')
  -- Options: 'eol', 'eol_right_align', 'inline', 'overlay', 'right_align'
  virt_text_pos = 'right_align',

  -- Map eza git status to custom icons and highlights
  status_map = {
    -- Example: Hide "Not Modified" status
    -- ['--'] = { icon = '' },
    -- Add more mappings as needed
  },

  -- Default highlight when status is not mapped
  default_highlight = 'MiniFilesFile',
}
```

## API

### `clear_cache(path?)`

Clear the git status cache. Useful after external git operations.

```lua
-- Clear all cache
require('t1ckbase.mini-files-git-status').clear_cache()

-- Clear cache for a specific directory
require('t1ckbase.mini-files-git-status').clear_cache('/path/to/dir')
```

## Credits

Inspired by:

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- [mini.nvim discussion #1701](https://github.com/nvim-mini/mini.nvim/discussions/1701)
- [bassamsdata's gist](https://gist.github.com/bassamsdata/eec0a3065152226581f8d4244cce9051)
