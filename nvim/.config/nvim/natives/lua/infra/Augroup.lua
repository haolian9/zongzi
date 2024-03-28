local api = vim.api

---@alias infra.AugroupEvent
---| '"BufAdd"'               # Just after creating a new buffer which is
---| '"BufDelete"'            # Before deleting a buffer from the buffer list.
---| '"BufEnter"'             # After entering a buffer.  Useful for setting
---| '"BufFilePost"'          # After changing the name of the current buffer
---| '"BufFilePre"'           # Before changing the name of the current buffer
---| '"BufHidden"'            # Before a buffer becomes hidden: when there are
---| '"BufLeave"'             # Before leaving to another buffer.  Also when
---| '"BufModifiedSet"'       # After the `'modified'` value of a buffer has
---| '"BufNew"'               # Just after creating a new buffer.  Also used
---| '"BufNewFile"'           # When starting to edit a file that doesn't
---| '"BufRead"'
---| '"BufReadPost"'          # When starting to edit a new buffer, after
---| '"BufReadCmd"'           # Before starting to edit a new buffer.  Should
---| '"BufReadPre"'           # When starting to edit a new buffer, before
---| '"BufUnload"'            # Before unloading a buffer, when the text in
---| '"BufWinEnter"'          # After a buffer is displayed in a window.  This
---| '"BufWinLeave"'          # Before a buffer is removed from a window.
---| '"BufWipeout"'           # Before completely deleting a buffer.  The
---| '"BufWrite"'
---| '"BufWritePre"'          # Before writing the whole buffer to a file.
---| '"BufWriteCmd"'          # Before writing the whole buffer to a file.
---| '"BufWritePost"'         # After writing the whole buffer to a file
---| '"ChanInfo"'             # State of channel changed, for instance the
---| '"ChanOpen"'             # Just after a channel was opened.
---| '"CmdUndefined"'         # When a user command is used but it isn't
---| '"CmdlineChanged"'       # After a change was made to the text inside
---| '"CmdlineEnter"'         # After entering the command-line (including
---| '"CmdlineLeave"'         # Before leaving the command-line (including
---| '"CmdwinEnter"'          # After entering the command-line window.
---| '"CmdwinLeave"'          # Before leaving the command-line window.
---| '"ColorScheme"'          # After loading a color scheme. |:colorscheme|
---| '"ColorSchemePre"'       # Before loading a color scheme. |:colorscheme|
---| '"CompleteChanged"'      # *CompleteChanged*
---| '"CompleteDonePre"'      # After Insert mode completion is done.  Either
---| '"CompleteDone"'         # After Insert mode completion is done.  Either
---| '"CursorHold"'           # When the user doesn't press a key for the time
---| '"CursorHoldI"'          # Like CursorHold, but in Insert mode. Not
---| '"CursorMoved"'          # After the cursor was moved in Normal or Visual
---| '"CursorMovedI"'         # After the cursor was moved in Insert mode.
---| '"DiffUpdated"'          # After diffs have been updated.  Depending on
---| '"DirChanged"'           # After the |current-directory| was changed.
---| '"DirChangedPre"'        # When the |current-directory| is going to be
---| '"ExitPre"'              # When using `:quit`, `:wq` in a way it makes
---| '"FileAppendCmd"'        # Before appending to a file.  Should do the
---| '"FileAppendPost"'       # After appending to a file.
---| '"FileAppendPre"'        # Before appending to a file.  Use the '[ and ']
---| '"FileChangedRO"'        # Before making the first change to a read-only
---| '"FileChangedShell"'     # When Vim notices that the modification time of
---| '"FileChangedShellPost"' # After handling a file that was changed outside
---| '"FileReadCmd"'          # Before reading a file with a ":read" command.
---| '"FileReadPost"'         # After reading a file with a ":read" command.
---| '"FileReadPre"'          # Before reading a file with a ":read" command.
---| '"FileType"'             # When the 'filetype' option has been set.  The
---| '"FileWriteCmd"'         # Before writing to a file, when not writing the
---| '"FileWritePost"'        # After writing to a file, when not writing the
---| '"FileWritePre"'         # Before writing to a file, when not writing the
---| '"FilterReadPost"'       # After reading a file from a filter command.
---| '"FilterReadPre"'        # Before reading a file from a filter command.
---| '"FilterWritePost"'      # After writing a file for a filter command or
---| '"FilterWritePre"'       # Before writing a file for a filter command or
---| '"FocusGained"'          # Nvim got focus.
---| '"FocusLost"'            # Nvim lost focus.  Also (potentially) when
---| '"FuncUndefined"'        # When a user function is used but it isn't
---| '"UIEnter"'              # After a UI connects via |nvim_ui_attach()|, or
---| '"UILeave"'              # After a UI disconnects from Nvim, or after
---| '"InsertChange"'         # When typing <Insert> while in Insert or
---| '"InsertCharPre"'        # When a character is typed in Insert mode,
---| '"InsertEnter"'          # Just before starting Insert mode.  Also for
---| '"InsertLeavePre"'       # Just before leaving Insert mode.  Also when
---| '"InsertLeave"'          # Just after leaving Insert mode.  Also when
---| '"MenuPopup"'            # Just before showing the popup menu (under the
---| '"ModeChanged"'          # After changing the mode. The pattern is
---| '"OptionSet"'            # After setting an option (except during
---| '"QuickFixCmdPre"'       # Before a quickfix command is run (|:make|,
---| '"QuickFixCmdPost"'      # Like QuickFixCmdPre, but after a quickfix
---| '"QuitPre"'              # When using `:quit`, `:wq` or `:qall`, before
---| '"RemoteReply"'          # When a reply from a Vim that functions as
---| '"SearchWrapped"'        # After making a search with |n| or |N| if the
---| '"RecordingEnter"'       # When a macro starts recording.
---| '"RecordingLeave"'       # When a macro stops recording.
---| '"SessionLoadPost"'      # After loading the session file created using
---| '"ShellCmdPost"'         # After executing a shell command with |:!cmd|,
---| '"Signal"'               # After Nvim receives a signal. The pattern is
---| '"ShellFilterPost"'      # After executing a shell command with
---| '"SourcePre"'            # Before sourcing a vim/lua file. |:source|
---| '"SourcePost"'           # After sourcing a vim/lua file. |:source|
---| '"SourceCmd"'            # When sourcing a vim/lua file. |:source|
---| '"SpellFileMissing"'     # When trying to load a spell checking file and
---| '"StdinReadPost"'        # During startup, after reading from stdin into
---| '"StdinReadPre"'         # During startup, before reading from stdin into
---| '"SwapExists"'           # Detected an existing swap file when starting
---| '"Syntax"'               # When the 'syntax' option has been set.  The
---| '"TabEnter"'             # Just after entering a tab page. |tab-page|
---| '"TabLeave"'             # Just before leaving a tab page. |tab-page|
---| '"TabNew"'               # When creating a new tab page. |tab-page|
---| '"TabNewEntered"'        # After entering a new tab page. |tab-page|
---| '"TabClosed"'            # After closing a tab page. <afile> expands to
---| '"TermOpen"'             # When a |terminal| job is starting.  Can be
---| '"TermEnter"'            # After entering |Terminal-mode|.
---| '"TermLeave"'            # After leaving |Terminal-mode|.
---| '"TermClose"'            # When a |terminal| job ends.
---| '"TermResponse"'         # After the response to t_RV is received from
---| '"TextChanged"'          # After a change was made to the text in the
---| '"TextChangedI"'         # After a change was made to the text in the
---| '"TextChangedP"'         # After a change was made to the text in the
---| '"TextChangedT"'         # After a change was made to the text in the
---| '"TextYankPost"'         # Just after a |yank| or |deleting| command, but not
---| '"User"'                 # Not executed automatically.  Use |:doautocmd|
---| '"UserGettingBored"'     # When the user presses the same key 42 times.
---| '"VimEnter"'             # After doing all the startup stuff, including
---| '"VimLeave"'             # Before exiting Vim, just after writing the
---| '"VimLeavePre"'          # Before exiting Vim, just before writing the
---| '"VimResized"'           # After the Vim window was resized, thus 'lines'
---| '"VimResume"'            # After Nvim resumes from |suspend| state.
---| '"VimSuspend"'           # Before Nvim enters |suspend| state.
---| '"WinClosed"'            # When closing a window, just before it is
---| '"WinEnter"'             # After entering another window.  Not done for
---| '"WinLeave"'             # Before leaving a window.  If the window to be
---| '"WinNew"'               # When a new window was created.  Not done for
---| '"WinScrolled"'          # After any window in the current tab page
---| '"WinResized"'           # After a window in the current tab page changed

--mandatory fields: group, (buffer vs. pattern)
---@class infra.AugroupCreateOpts
---@field bufnr? integer
---@field pattern? string|string[]
---@field desc? string
---@field callback fun(args: {id: integer, event: string, group?: integer, match: string, buf: integer, file: string, data: any}): nil|true
---@field command? string @exclusive to callback
---@field once? boolean @nil=false
---@field nested? boolean @nil=false
---@field group? integer @should only be set by Augroup internally

local Augroup
do
  ---@class infra.Augroup
  ---@field group integer
  ---@field free_count integer
  ---@field autounlink? boolean @nil=unset
  local Prototype = {}

  Prototype.__index = Prototype

  ---@private
  ---@param event infra.AugroupEvent|infra.AugroupEvent[]
  ---@param opts infra.AugroupCreateOpts
  ---@return integer @autocmd id
  function Prototype:append_aucmd(event, opts)
    opts.group = self.group
    return api.nvim_create_autocmd(event, opts)
  end

  ---@param event infra.AugroupEvent|infra.AugroupEvent[]
  ---@param opts infra.AugroupCreateOpts
  function Prototype:repeats(event, opts)
    assert(opts.once ~= true)
    return self:append_aucmd(event, opts)
  end

  ---@param event infra.AugroupEvent|infra.AugroupEvent[]
  ---@param opts infra.AugroupCreateOpts
  function Prototype:once(event, opts)
    opts.once = true
    return self:append_aucmd(event, opts)
  end

  function Prototype:unlink() api.nvim_del_augroup_by_id(self.group) end

  ---mandatory clearing augroup
  ---@param fmt string
  ---@param ... any
  ---@return infra.Augroup
  function Augroup(fmt, ...)
    local group = api.nvim_create_augroup(string.format(fmt, ...), { clear = true })

    return setmetatable({ group = group, free_count = 0 }, Prototype)
  end
end

local M = {}
do
  ---@param bufnr integer
  ---@param autounlink? boolean @nil=false
  ---@return infra.Augroup
  function M.buf(bufnr, autounlink)
    assert(bufnr ~= nil and bufnr ~= 0)
    if autounlink == nil then autounlink = false end
    local aug = Augroup("aug://buf/%d", bufnr)

    do
      aug.autounlink = false -- set it to false explicitly
      ---@diagnostic disable: invisible
      local orig = aug.append_aucmd
      function aug:append_aucmd(event, opts)
        if self.autounlink and string.lower(event) == "bufwipeout" then error("conflicted with autounlink") end
        opts.buffer = bufnr
        return orig(aug, event, opts)
      end
    end

    if autounlink then
      aug:once("BufWipeout", { callback = function() aug:unlink() end })
      aug.autounlink = autounlink
    end

    return aug
  end

  ---@param winid integer
  ---@param autounlink? boolean @nil=false
  ---@return infra.Augroup
  function M.win(winid, autounlink)
    assert(winid ~= nil and winid ~= 0)
    if autounlink == nil then autounlink = false end
    local aug = Augroup("aug://win/%d", winid)

    do
      aug.autounlink = false -- set it to false explicitly
      ---@diagnostic disable: invisible
      local orig = aug.append_aucmd
      function aug:append_aucmd(event, opts)
        if self.autounlink and string.lower(event) == "winclosed" then error("conflicted with autounlink") end
        return orig(aug, event, opts)
      end
    end

    if autounlink then
      aug:repeats("WinClosed", {
        callback = function(args)
          local this_winid = assert(tonumber(args.match))
          if this_winid ~= winid then return end
          aug:unlink()
          return true
        end,
      })
      aug.autounlink = autounlink
    end

    return aug
  end
end

---@overload fun(name: string): infra.Augroup
local mod = setmetatable({}, { __index = M, __call = function(_, name) return Augroup(name) end })

return mod
