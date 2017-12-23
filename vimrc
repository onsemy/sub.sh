" vim:ft=vim:et:ts=2:sw=2:sts=2:

call plug#begin('~/.vim/plugged')
" plugins ---------------------------------------------------------------------

" syntax highlighters
Plug 'plasticboy/vim-markdown'
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'othree/html5.vim'
if version < 704
  Plug 'JulesWang/css.vim'
endif
Plug 'cakebaker/scss-syntax.vim'
Plug 'stephpy/vim-yaml'
Plug 'cespare/vim-toml'
Plug 'rust-lang/rust.vim'
Plug 'ekalinin/Dockerfile.vim'

" function extensions
Plug 'easymotion/vim-easymotion'
Plug 'hashivim/vim-terraform'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'hotwatermorning/auto-git-diff'
Plug 'rhysd/committia.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'simnalamburt/vim-mundo'
Plug 'tmhedberg/matchit'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-unimpaired'
Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
Plug 'w0rp/ale'

" -----------------------------------------------------------------------------
call plug#end()

" Syntax highlighting.
syntax on

" Prefer "very magic" regex.
nnoremap / /\v
cnoremap %s/ %s/\v

" Search for visually selected text by //.
vnoremap // y/<C-R>"<CR>

" I dislike CRLF.
set fileformat=unix

" Make backspace works like most other applications.
set backspace=2

" Detect modeline hints.
set modeline

" Prefer UTF-8.
set encoding=utf-8 fileencodings=ucs-bom,utf-8,cp949,korea,iso-2022-kr

" Ignore case in searches.
set ignorecase

" Highlight searching keyword.
set hlsearch
highlight Search term=inverse cterm=none ctermbg=cyan

" Softtab -- use spaces instead tabs.
set et
set ts=4 sw=4 sts=4
set ai
highlight HardTab term=underline cterm=underline
au BufWinEnter * 2 match HardTab /\t\+/

" Some additional syntax highlighters.
au! BufRead,BufNewFile *.wsgi setfiletype python
au! BufRead,BufNewFile *.sass setfiletype sass
au! BufRead,BufNewFile *.haml setfiletype haml
au! BufRead,BufNewFile *.less setfiletype less
au! BufRead,BufNewFile *go setfiletype golang
au! BufRead,BufNewFile *rc setfiletype conf
au! BufRead,BufNewFile *.*_t setfiletype jinja

" Set language-specific tab/indent/columns conventions.
au FileType cpp        setl ts=2 sw=2 sts=2
au FileType javascript setl ts=2 sw=2 sts=2
au FileType ruby       setl ts=2 sw=2 sts=2
au FileType xml        setl ts=2 sw=2 sts=2
au FileType yaml       setl ts=2 sw=2 sts=2
au FileType html       setl ts=2 sw=2 sts=2
au FileType htmldjango setl ts=2 sw=2 sts=2
au FileType lua        setl ts=2 sw=2 sts=2
au FileType haml       setl ts=2 sw=2 sts=2
au FileType css        setl ts=2 sw=2 sts=2
au FileType sass       setl ts=2 sw=2 sts=2
au FileType less       setl ts=2 sw=2 sts=2
au Filetype rst        setl ts=3 sw=3 sts=3
au FileType golang     setl noet
au FileType make       setl ts=4 sw=4 sts=4 noet
au FileType python     setl ts=4 sw=4 sts=4 | let b:maxcol=79

" Keep maximum columns, avoid trailing empty lines.
" Let b:maxcol to set the maximum columns.
highlight ColorColumn term=underline cterm=underline ctermbg=none
au BufWinEnter *
\ if exists('b:maxcol')
\|  execute 'set colorcolumn='.(b:maxcol+1)
\|  execute 'match Error /\%>'.(b:maxcol).'v.\+\|\s\+$\|^\s*\n\+\%$/'
\|else
\|  match Error /\s\+$\|^\s*\n\+\%$/
\|endif

" English spelling checker.
setlocal spelllang=en_us

" Always show sign column.
au BufEnter * sign define sign
au BufEnter * execute 'sign place 9999 line=1 name=sign buffer='.bufnr('')

" Change gutter color.
hi SignColumn cterm=none ctermfg=none ctermbg=black

" ALE
au VimEnter *
\ if exists(':ALE')
\|  let g:ale_sign_column_always       = 1
\|  let g:ale_statusline_format        = ['E%d', 'W%d', '']
\|  let g:ale_echo_msg_format          = '[%linter%] %s [%severity%]'
\|  let g:ale_lint_delay               = 500
\|  let g:ale_lint_on_text_changed     = 'normal'
\|  nmap <silent> <C-k> <Plug>(ale_previous_wrap)
\|  nmap <silent> <C-j> <Plug>(ale_next_wrap)
\|endif

" It blocks editing.
" \|  let g:ale_change_sign_column_color = 1

" Customize status line.
"
" E1 works/project/main.c [c][+]                                      29:2/1232
" │         └─ file path   │  └─ modified flag           current line ─┘ │  │
" └─ ALE status line       └─ file type                  current column ─┘  │
"                                                              total lines ─┘
"
function ALEGetStatusLine()
  " Status line fallback when ALE is not available.
  return ''
endfunction
set statusline=
set statusline+=%1*%{ALEGetStatusLine()}%*  " ALE status line
set statusline+=\ %f                        " file path
set statusline+=\ %y                        " file type
set statusline+=%m                          " modified flag
set statusline+=%=
set statusline+=%l                          " current line
set statusline+=:%v                         " current column
set statusline+=/%L                         " total lines
hi User1 cterm=inverse ctermfg=red

" YouCompleteMe
au VimEnter *
\ if exists('g:ycm_goto_buffer_command')
\|  let g:ycm_goto_buffer_command = 'new-tab'
\|  nnoremap <F12> :YcmCompleter GoToDefinition<CR>
\|endif

" Mundo
au VimEnter *
\ if exists(':Mundo')
\|  nnoremap <F5> :MundoToggle<CR>
\|endif

" EasyMotion
au VimEnter *
\ if exists('g:EasyMotion_loaded')
\|  map <Leader>l <Plug>(easymotion-lineforward)
\|  map <Leader>j <Plug>(easymotion-j)
\|  map <Leader>k <Plug>(easymotion-k)
\|  map <Leader>h <Plug>(easymotion-linebackward)
\|endif

" Explore the directory of the current file by `:E`.
cabbrev E e %:p:h

" Disable Markdown folding.
let g:vim_markdown_folding_disabled=1

" Customize colors for Jinja syntax.
hi def link jinjaVarBlock Comment

" For Terraform.
let g:terraform_fold_sections=1
let g:terraform_remap_spacebar=1
au FileType tf setlocal commentstring=#\ %s

" fzf
au VimEnter *
\ if exists(':FZF')
\|  nnoremap <C-f> :FZF<CR>
\|endif
