" tokyonight.vim — Tokyo Night palette (night variant)
" Hand-rolled colourscheme; no upstream port for vanilla vim is maintained.

hi clear
if exists('syntax_on')
    syntax reset
endif
let g:colors_name = 'tokyonight'

if !(has('termguicolors') && &termguicolors) && !has('gui_running')
    finish
endif

" --- Palette ---
let s:base     = '#1a1b26'
let s:surface  = '#16161e'
let s:overlay  = '#0c0e14'
let s:muted    = '#565f89'
let s:subtle   = '#a9b1d6'
let s:text     = '#c0caf5'
let s:sakura   = '#f7768e'
let s:honey    = '#e0af68'
let s:ember    = '#ff9e64'
let s:bamboo   = '#9ece6a'
let s:jade     = '#73daca'
let s:glacier  = '#7dcfff'
let s:cobalt   = '#7aa2f7'
let s:wisteria = '#bb9af7'
let s:orchid   = '#9d7cd8'
let s:hl_lo    = '#292e42'
let s:hl_mid   = '#283457'
let s:hl_hi    = '#3b4261'

function! s:hi(group, fg, bg, attr) abort
    let l:cmd = 'highlight ' . a:group
    if !empty(a:fg)   | let l:cmd .= ' guifg=' . a:fg | endif
    if !empty(a:bg)   | let l:cmd .= ' guibg=' . a:bg | endif
    if !empty(a:attr) | let l:cmd .= ' gui=' . a:attr . ' cterm=' . a:attr | endif
    execute l:cmd
endfunction

" --- UI ---
call s:hi('Normal',         s:text,    s:base,   '')
call s:hi('NormalFloat',    s:text,    s:surface,'')
call s:hi('NormalNC',       s:subtle,  s:base,   '')
call s:hi('LineNr',         s:hl_hi,   '',       '')
call s:hi('CursorLineNr',   s:honey,   '',       'bold')
call s:hi('CursorLine',     '',        s:hl_lo,  '')
call s:hi('CursorColumn',   '',        s:hl_lo,  '')
call s:hi('ColorColumn',    '',        s:surface,'')
call s:hi('SignColumn',     s:subtle,  s:base,   '')
call s:hi('FoldColumn',     s:hl_hi,   s:base,   '')
call s:hi('Folded',         s:subtle,  s:hl_lo,  'italic')
call s:hi('VertSplit',      s:hl_hi,   s:base,   '')
call s:hi('WinSeparator',   s:hl_hi,   s:base,   '')
call s:hi('StatusLine',     s:subtle,  s:hl_mid, '')
call s:hi('StatusLineNC',   s:muted,   s:hl_lo,  '')
call s:hi('TabLine',        s:subtle,  s:hl_lo,  '')
call s:hi('TabLineFill',    '',        s:base,   '')
call s:hi('TabLineSel',     s:text,    s:hl_mid, 'bold')
call s:hi('Visual',         '',        s:hl_mid, '')
call s:hi('VisualNOS',      '',        s:hl_mid, '')
call s:hi('Search',         s:base,    s:honey,  '')
call s:hi('IncSearch',      s:base,    s:ember,  '')
call s:hi('CurSearch',      s:base,    s:ember,  'bold')
call s:hi('MatchParen',     s:ember,   s:hl_hi,  'bold')
call s:hi('Pmenu',          s:subtle,  s:surface,'')
call s:hi('PmenuSel',       s:text,    s:hl_mid, 'bold')
call s:hi('PmenuSbar',      '',        s:hl_lo,  '')
call s:hi('PmenuThumb',     '',        s:hl_hi,  '')
call s:hi('WildMenu',       s:base,    s:cobalt, '')
call s:hi('Title',          s:cobalt,  '',       'bold')
call s:hi('Question',       s:bamboo,  '',       '')
call s:hi('Directory',      s:cobalt,  '',       '')
call s:hi('ErrorMsg',       s:sakura,  '',       'bold')
call s:hi('WarningMsg',     s:honey,   '',       '')
call s:hi('ModeMsg',        s:subtle,  '',       '')
call s:hi('MoreMsg',        s:bamboo,  '',       '')
call s:hi('Conceal',        s:muted,   '',       '')
call s:hi('NonText',        s:hl_hi,   '',       '')
call s:hi('SpecialKey',     s:hl_hi,   '',       '')
call s:hi('Whitespace',     s:hl_hi,   '',       '')
call s:hi('EndOfBuffer',    s:base,    s:base,   '')
call s:hi('Cursor',         s:base,    s:text,   '')
call s:hi('lCursor',        s:base,    s:text,   '')
call s:hi('TermCursor',     s:base,    s:text,   '')
call s:hi('QuickFixLine',   '',        s:hl_mid, '')

" --- Spell ---
call s:hi('SpellBad',       s:sakura,  '',       'underline')
call s:hi('SpellCap',       s:cobalt,  '',       'underline')
call s:hi('SpellLocal',     s:jade,    '',       'underline')
call s:hi('SpellRare',      s:wisteria,'',       'underline')

" --- Diff ---
call s:hi('DiffAdd',        s:bamboo,  s:hl_lo,  '')
call s:hi('DiffChange',     s:honey,   s:hl_lo,  '')
call s:hi('DiffDelete',     s:sakura,  s:hl_lo,  '')
call s:hi('DiffText',       s:base,    s:honey,  'bold')

" --- Diagnostics (vim 9+) ---
call s:hi('DiagnosticError',s:sakura,  '',       '')
call s:hi('DiagnosticWarn', s:honey,   '',       '')
call s:hi('DiagnosticInfo', s:cobalt,  '',       '')
call s:hi('DiagnosticHint', s:jade,    '',       '')

" --- Syntax ---
call s:hi('Comment',        s:muted,   '',       'italic')
call s:hi('Todo',           s:base,    s:honey,  'bold')
call s:hi('Error',          s:text,    s:sakura, '')

call s:hi('Constant',       s:ember,   '',       '')
call s:hi('String',         s:bamboo,  '',       '')
call s:hi('Character',      s:bamboo,  '',       '')
call s:hi('Number',         s:ember,   '',       '')
call s:hi('Float',          s:ember,   '',       '')
call s:hi('Boolean',        s:ember,   '',       'bold')

call s:hi('Identifier',     s:text,    '',       '')
call s:hi('Function',       s:cobalt,  '',       '')

call s:hi('Statement',      s:wisteria,'',       '')
call s:hi('Conditional',    s:wisteria,'',       '')
call s:hi('Repeat',         s:wisteria,'',       '')
call s:hi('Label',          s:wisteria,'',       '')
call s:hi('Operator',       s:glacier, '',       '')
call s:hi('Keyword',        s:wisteria,'',       '')
call s:hi('Exception',      s:sakura,  '',       '')

call s:hi('PreProc',        s:jade,    '',       '')
call s:hi('Include',        s:wisteria,'',       '')
call s:hi('Define',         s:wisteria,'',       '')
call s:hi('Macro',          s:jade,    '',       '')
call s:hi('PreCondit',      s:jade,    '',       '')

call s:hi('Type',           s:glacier, '',       '')
call s:hi('StorageClass',   s:glacier, '',       '')
call s:hi('Structure',      s:glacier, '',       '')
call s:hi('Typedef',        s:glacier, '',       '')

call s:hi('Special',        s:jade,    '',       '')
call s:hi('SpecialChar',    s:ember,   '',       '')
call s:hi('Tag',            s:sakura,  '',       '')
call s:hi('Delimiter',      s:subtle,  '',       '')
call s:hi('SpecialComment', s:cobalt,  '',       'italic')
call s:hi('Debug',          s:ember,   '',       '')

call s:hi('Underlined',     s:cobalt,  '',       'underline')
call s:hi('Ignore',         s:muted,   '',       '')

" --- Markdown ---
hi! link markdownH1                 Title
hi! link markdownH2                 Title
hi! link markdownH3                 Title
hi! link markdownH4                 Title
hi! link markdownH5                 Title
hi! link markdownH6                 Title
hi! link markdownCode               String
hi! link markdownCodeBlock          String
hi! link markdownLinkText           Underlined
hi! link markdownUrl                Underlined
hi! link markdownListMarker         Operator
hi! link markdownBlockquote         Comment

" --- Diff filetype ---
hi! link diffAdded                  DiffAdd
hi! link diffRemoved                DiffDelete
hi! link diffChanged                DiffChange
hi! link diffFile                   Title
hi! link diffLine                   Comment
hi! link diffIndexLine              Comment
hi! link diffSubname                Type

delfunction s:hi
