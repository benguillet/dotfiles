set nocompatible 
set confirm

" Vundle config
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" =======
" Bundles
" =======

Plugin 'gmarik/Vundle.vim'
Plugin 'bling/vim-airline'
Plugin 'airblade/vim-gitgutter'
Plugin 'kien/ctrlp.vim'

" Syntax
Plugin 'fatih/vim-go'


" Color schemes
Plugin 'nanotech/jellybeans.vim'
Plugin 'chriskempson/base16-vim'

call vundle#end()
filetype plugin indent on

" ========
" Settings
" ========

" Color schemes
" Activate syntax highlighting
syntax on 
set background=dark
" colorscheme jellybeans
colorscheme base16-railscasts

" Railscast colorscheme
highlight clear SignColumn
highlight VertSplit    ctermbg=236
highlight ColorColumn  ctermbg=237
highlight LineNr       ctermbg=236 ctermfg=240
highlight CursorLineNr ctermbg=236 ctermfg=240
highlight CursorLine   ctermbg=236
highlight StatusLineNC ctermbg=238 ctermfg=0
highlight StatusLine   ctermbg=240 ctermfg=12
highlight IncSearch    ctermbg=0   ctermfg=3
highlight Search       ctermbg=0   ctermfg=9
highlight Visual       ctermbg=3   ctermfg=0
highlight Pmenu        ctermbg=240 ctermfg=12
highlight PmenuSel     ctermbg=0   ctermfg=3
highlight SpellBad     ctermbg=0   ctermfg=1

set bs=2                         " Backspacing over everything in insert mode
set autoindent                   " Auto indenting
set history=100                  " Keep 100 lines of history
set expandtab                    " Use spaces instaed of tabs
set softtabstop=2                " how many spaces for one tab
set tabstop=2
set shiftwidth=2                 " # of spaces when autoindent
set smartindent
set cindent
set number
set encoding=utf-8
set scrolloff=5
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set visualbell
set ttyfast
set backspace=indent,eol,start
set laststatus=2
set showmatch
set viminfo='20,\"200           " keep a .viminfo file
set hlsearch                    " highlight the last searched term
set incsearch
set wrap
set textwidth=79
set formatoptions=qrn1
set colorcolumn=85
set nofoldenable
set nobackup
set noswapfile
set undodir=~/.vim/undo
set undofile
set undolevels=1000
set undoreload=10000
"set cursorline

" When editing a file, always jump to the last cursor position
autocmd BufReadPost *
\ if ! exists("g:leave_my_cursor_position_alone") |
\ if line("'\"") > 0 && line ("'\"") <= line("$") |
\ exe "normal g'\"" |
\ endif |
\ endif

" Deactivate arrow keys
noremap <Up>    <NOP>
noremap <Down>  <NOP>
noremap <Left>  <NOP>
noremap <Right> <NOP>

" Autotrail whitespaces
fun! <SID>StripTrailingWhitespaces()
    let l = line(".")
    let c = col(".")
    %s/\s\+$//e
    call cursor(l, c)
endfun

set completeopt=menu,menuone
