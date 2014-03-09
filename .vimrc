set nocompatible 

" Vundle config
filetype off

set rtp+=~/.vim/bundle/vundle/\
call vundle#rc()

Bundle 'gmarik/vundle'
Bundle 'bling/vim-airline'
Bundle 'airblade/vim-gitgutter'

" Color schemes
Bundle 'nanotech/jellybeans.vim'
Bundle 'tomasr/molokai'

filetype on
filetype plugin on
filetype plugin indent on

" Color schemes
syntax on                        " Activate syntax highlighting
" colorscheme molokai
colorscheme jellybeans

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
set background=dark

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
