" ====================================================================
" claude-agent.vim
" Send visual selection (if any) to Claude in a new vertical iTerm2 pane
" ====================================================================

function! s:GetRangeAndText()
  let l:start = line("'<")
  let l:end   = line("'>")

  if l:start > 0 && l:end > 0 && (l:start != l:end || col("'<") != col("'>"))
    let l:lines = getline(l:start, l:end)
    let l:text  = join(l:lines, "\n")

    while l:text =~# '\n\s*$'
      let l:text = substitute(l:text, '\n\s*$', '', '')
    endwhile

    return [l:start, l:end, l:text]
  endif

  return ['', '', '']
endfunction


function! ClaudeAgentSend()
  let [l:start, l:end, l:text] = s:GetRangeAndText()
  let l:has_selection = (l:start !=# '' && l:end !=# '' && l:text !=# '')

  let l:file = expand('%:p')

  let l:project_root = substitute(system('git rev-parse --show-toplevel'), '\n', '', '')
  if empty(l:project_root)
    let l:project_root = expand('%:p:h')
  endif

  let l:preamble = ''

  if l:has_selection
    let l:relfile = substitute(l:file, '^' . l:project_root . '/', '', '')

    if l:start == l:end
      let l:range = 'line ' . l:start
    else
      let l:range = 'lines ' . l:start . ' to ' . l:end
    endif

    " Claude-friendly instruction
    let l:preamble = join([
    \ 'You are working in the following file:',
    \ l:relfile . ' (' . l:range . ')',
    \ '',
    \ 'Here is the relevant code:',
    \ '```',
    \ l:text,
    \ '```',
    \ '',
    \ 'Please help with the following:'
    \ ], "\n")

    let l:preamble = substitute(l:preamble, '"', '\\\"', 'g')
  endif

  let l:script = [
  \ 'tell application "iTerm2"',
  \ '  tell current window',
  \ '    tell current session',
  \ '      set newPane to (split vertically with profile "Default")',
  \ '    end tell',
  \ '    tell newPane',
  \ '      write text "cd ' . l:project_root . '"',
  \ '      delay 0.2',
  \ '      write text "claude"',
  \ '      delay 0.6'
  \ ]

  if l:preamble !=# ''
    call add(l:script, '      write text "' . l:preamble . '"')
  endif

  call extend(l:script, [
  \ '    end tell',
  \ '  end tell',
  \ 'end tell'
  \ ])

  let l:tmp = tempname()
  call writefile(l:script, l:tmp)
  call system('osascript ' . shellescape(l:tmp))
  call delete(l:tmp)
endfunction


" ====================================================================
" COMMAND + MAPPINGS
" ====================================================================
command! ClaudeAsk call ClaudeAgentSend()

nnoremap <silent> <leader>cl :ClaudeAsk<CR>
xnoremap <silent> <leader>cl :<C-u>ClaudeAsk<CR>
inoremap <silent> <leader>cl <Esc>:ClaudeAsk<CR>
