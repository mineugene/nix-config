{
    config,
    pkgs,
    lib,
    ...
}:
{
    programs.vim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
            auto-pairs
            splitjoin-vim
            targets-vim
            vim-commentary
            vim-indent-object
            vim-mucomplete
            vim-repeat
            vim-sleuth
            vim-surround
            vim-unimpaired
        ];
    };

    home.file.".vim/colors/tokyonight.vim".source = ./colors/tokyonight.vim;

    home.sessionVariables = {
        EDITOR = lib.mkDefault "vim";
        VISUAL = lib.mkDefault "vim";
    };

    home.shellAliases = {
        vi = lib.mkDefault "command vim";
    };

    home.file.".vim/vimrc".text = ''
        " --- Plugins ---
        packadd! matchit

        " --- Leader ---
        let mapleader = ' '
        let maplocalleader = ' '

        " --- Plugin Config ---
        " mucomplete
        let g:mucomplete#enable_auto_at_startup = 1
        let g:mucomplete#completion_delay = 100
        let g:mucomplete#chains = { 'default': ['path', 'omni', 'keyn', 'dict', 'uspl'] }

        " auto-pairs
        let g:AutoPairsMapCR = 1
        let g:AutoPairsShortcutToggle = '''

        " --- Options ---
        set background=dark
        set cmdheight=1
        set colorcolumn=80
        set cursorline
        set nocursorcolumn
        set laststatus=2
        set list
        set listchars=tab:>·,trail:·,extends:›,precedes:‹
        set number
        set relativenumber
        set noshowmode
        silent! set signcolumn=yes
        set spell
        set spelllang=en_ca,en
        set nowrap

        set gdefault
        set ignorecase
        set smartcase
        set hlsearch
        set incsearch

        set expandtab
        set shiftwidth=4
        set smartindent
        set softtabstop=4
        set tabstop=4

        set noequalalways
        set scrolloff=4
        set sidescrolloff=2
        set splitbelow
        set splitright

        set completeopt=menuone,noselect
        set shortmess+=c
        set wildignore+=.git/**,node_modules/**,dist/**,result/**,.direnv/**
        set wildignore+=build/**,.cache/**,tmp/**,.vs/**,**/bin/**,**/obj/**
        set wildignore+=*.dll,*.exe,*.pdb,.venv/**,venv/**
        set wildignore+=**/__pycache__/**,**/*.egg-info/**,*.pyc,*.pyo
        set wildignore+=**/vendor/**,target/**,*.rlib

        set nobackup
        set noswapfile
        set path=.,/usr/include,**
        set synmaxcol=256
        set textwidth=0
        set updatetime=200
        set hidden
        set backspace=indent,eol,start
        set ttimeoutlen=50

        " --- Keymaps ---
        nnoremap <Esc> :nohlsearch<CR>
        nnoremap <leader>h :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>
        xnoremap <leader>h "hy:%s/<C-r>h//gI<Left><Left><Left>
        xnoremap p "_dP
        xnoremap < <gv
        xnoremap > >gv
        nnoremap <M-z> :set wrap!<CR>

        " --- Autocommands ---
        augroup vimrc_insert
            autocmd!
            autocmd InsertEnter * set norelativenumber nospell
            autocmd InsertLeave * set relativenumber spell
        augroup END

        augroup vimrc_formatoptions
            autocmd!
            autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
        augroup END

        augroup vimrc_terminal
            autocmd!
            if has('terminal')
                autocmd TerminalOpen * setlocal nospell
                autocmd TerminalOpen * setlocal timeoutlen=250
                autocmd TerminalOpen * startinsert
                tnoremap <Esc><Esc> <C-\><C-n>:bd!<CR>
            endif
        augroup END

        augroup vimrc_spell
            autocmd!
            autocmd FileType qf,help setlocal nospell
        augroup END

        " --- Colorscheme ---
        if has('termguicolors')
            set termguicolors
        endif
        syntax enable
        colorscheme tokyonight
    '';
}
