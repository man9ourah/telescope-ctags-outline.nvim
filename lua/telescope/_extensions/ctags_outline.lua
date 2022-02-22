local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
    error('telescope-ctags-outline.nvim requires nvim-telescope/telescope.nvim')
end

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local ctags_bin = "ctags"
local ctags_opt = {}
local ft_opt = {
  ant        = '--language-force=ant --ant-kinds=pt',
  asm        = '--language-force=asm --asm-kinds=sdlmt',
  aspperl    = '--language-force=asp --asp-kinds=cdvfs',
  aspvbs     = '--language-force=asp --asp-kinds=cdvfs',
  awk        = '--language-force=awk --awk-kinds=f',
  basic      = '--language-force=basic --basic-kinds=clgvtf',
  beta       = '--language-force=beta --beta-kinds=fsv',
  c          = '--language-force=c --c-kinds=dgsutvf',
  cpp        = '--language-force=c++ --c++-kinds=nvdtcgsuf',
  cs         = '--language-force=c# --c#-kinds=dtncEgsipm',
  cobol      = '--language-force=cobol --cobol-kinds=dfgpPs',
  d          = '--language-force=c++ --c++-kinds=nvtcgsuf',
  dosbatch   = '--language-force=dosbatch --dosbatch-kinds=lv',
  eiffel     = '--language-force=eiffel --eiffel-kinds=cf',
  erlang     = '--language-force=erlang --erlang-kinds=drmf',
  expect     = '--language-force=tcl --tcl-kinds=cfp',
  flex       = '--language-force=flex --flex-kinds=vcpmfx',
  fortran    = '--language-force=fortran --fortran-kinds=pbceiklmntvfs',
  go         = '--language-force=go --go-kinds=psif',
  html       = '--language-force=html --html-kinds=acCJ',
  java       = '--language-force=java --java-kinds=pcigfm',
  javascript = '--language-force=javascript --javascript-kinds=cmvfp',
  lisp       = '--language-force=lisp --lisp-kinds=f',
  lua        = '--language-force=lua --lua-kinds=f',
  make       = '--language-force=make --make-kinds=mtI',
  matlab     = '--language-force=matlab --matlab-kinds=cfv',
  ocamal     = '--language-force=ocamal --ocamal-kinds=MvtcfmCe',
  pascal     = '--language-force=pascal --pascal-kinds=fp',
  perl       = '--language-force=perl --perl-kinds=clps',
  php        = '--language-force=php --php-kinds=ncidvf',
  python     = '--language-force=python --python-kinds=vcmf',
  pyrex      = '--language-force=python --python-kinds=cmf',
  rexx       = '--language-force=rexx --rexx-kinds=s',
  ruby       = '--language-force=ruby --ruby-kinds=cfFmS',
  scheme     = '--language-force=scheme --scheme-kinds=sf',
  sh         = '--language-force=sh --sh-kinds=af',
  csh        = '--language-force=sh --sh-kinds=af',
  zsh        = '--language-force=sh --sh-kinds=af',
  slang      = '--language-force=slang --slang-kinds=nf',
  sml        = '--language-force=sml --sml-kinds=ecsrtvcf',
  sql        = '--language-force=sql --sql-kinds=fPptTveURDxyzicVdlELrs',
  tcl        = '--language-force=tcl --tcl-kinds=cfmp',
  tex        = '--language-force=tex --tex-kinds=csubpPG',
  vera       = '--language-force=vera --vera-kinds=cdefgmpPtTvx',
  verilog    = '--language-force=verilog --verilog-kinds=mcPertwpvf',
  vhdl       = '--language-force=vhdl --vhdl-kinds=ctTrefpP',
  vim        = '--language-force=vim --vim-kinds=vacmf',
  yacc       = '--language-force=yacc --yacc-kinds=l',
  cmake      = '--language-force=cmake --cmake-kinds=mftvD',
  markdown   = '--language-force=markdown --markdown-kinds=csSt',
  rust       = '--language-force=rust --rust-kinds=nMgsicPf',
  css        = '--language-force=css --css-kinds=cfvi',
  kconfig    = '--language-force=kconfig --kconfig-kinds=cmkC',
  typescript = '--language-force=typescript --typescript-kinds=ncigvpf',
}

local function get_outline_entry (opts)
  opts = opts or {}

  -- create the displayer
  local displayer = entry_display.create {
      separator = " | ",
      items = {
          { width     = 5},
          { width     = 40 },
          { remaining = true },
      },
  }

  local function make_display(entry)
      return displayer {
        { entry.value.line, "TelescopeResultsLineNr" },
        { entry.value.name .. " (" .. entry.value.type .. ") ", "TelescopeResultsFunction" },
        { entry.value.source_line, "TelescopeResultsComment" },
      }
  end

  return function(entry)
      if entry == "" then
          return nil
      end

      local value = {}
      value.name, value.filename, value.type, value.line = string.match(entry, "(.-)\t(.-)\t.-\t(.-)\tline:(%d+)")
      value.lnum = tonumber(value.line)
      value.source_line = vim.fn.trim(vim.fn.getbufline(opts.bufnr, value.lnum)[1])

      return {
          filename = value.filename,
          lnum = value.lnum,
          value = value,
          ordinal = value.line .. value.type .. value.name,
          display = make_display
      }
  end
end

local tags = function(opts)
  opts = opts or {}
  local cmd = {}

  -- insert the binary name
  table.insert(cmd, ctags_bin)

  -- insert the options
  for _, v in ipairs(ctags_opt) do
      table.insert(cmd, v)
  end

  -- insert the kinds options based on the file type
  local bufnr = vim.fn.bufnr()
  local buftype = vim.fn.getbufvar(bufnr, "&filetype")
  local str = ("-n -u --fields=Kn %s -f-"):format(ft_opt[buftype] or "")
  for _, v in ipairs(vim.fn.split(str)) do
      table.insert(cmd, v)
  end

  -- insert the filename at last
  table.insert(cmd, vim.fn.expand("%:p"))

  -- join and execute the command (synchronously)
  local ctags_cmd = table.concat(cmd, " ")
  local ctags_out = vim.fn.system(ctags_cmd)
  if vim.v.shell_error ~= 0 or ctags_out == "" then
      error "Could not find tags in this file"
  end

  -- if we found something, then pass it on to telescope
  ctags_out = vim.split(ctags_out, "\n")

  -- now create the telescope picker
  opts.entry_maker = get_outline_entry(opts)
  opts.bufnr = bufnr
  pickers.new(opts, {
      prompt_title = "Ctags Outline",
      finder = finders.new_table({results = ctags_out, entry_maker = opts.entry_maker}),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              if selection then vim.cmd("normal " .. selection.lnum .. "G^") end
          end)
          return true
      end,
  }):find()
end

local grep = function (opts)
    require('telescope.builtin').current_buffer_fuzzy_find(opts)
end

local function search(opts)
    opts = opts or {}

    -- then we check if we can use tags
    local ok, _ = pcall(tags, opts)
    if ok then return end

    -- finally we just fallback to grep
    ok, _ = pcall(grep, opts)
end

return telescope.register_extension {
    setup = function(ext_config)
        ctags_bin = ext_config.ctags_bin or ctags_bin
        ctags_opt = ext_config.ctags_opt or ctags_opt
        if ext_config.set_ft_opt then
            ext_config.set_ft_opt(ft_opt)
        end
    end,
    exports = { search = search},
}
