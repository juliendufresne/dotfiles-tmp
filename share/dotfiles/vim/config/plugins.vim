" ========================
" Plugin manager
" ========================
" vim-plug (plug.vim) and the cloned plugins live under the XDG data home,
" NOT under ~/.vim. That distinction matters here: ~/.vim is the dotfiles
" symlink, so writing plugin code there would land it inside the tracked
" repo. The dotfiles installer downloads plug.vim and runs :PlugInstall from
" here at install time (see libexec/vim), so a plain `bin/dotfiles` leaves
" vim ready to use. The whole block is a no-op until plug.vim exists, so vim
" still starts without error when plugins are not installed.

let s:data_home = empty($XDG_DATA_HOME) ? expand('~/.local/share') : $XDG_DATA_HOME
let s:plug_home = s:data_home . '/vim'
let s:plug_file = s:plug_home . '/autoload/plug.vim'

if filereadable(s:plug_file)
  execute 'source ' . s:plug_file

  call plug#begin(s:plug_home . '/plugged')

  " File explorer
  Plug 'preservim/nerdtree'

  " Fuzzy finder
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'

  " Git
  Plug 'tpope/vim-fugitive'

  " Status line
  Plug 'itchyny/lightline.vim'

  " Commenting
  Plug 'tpope/vim-commentary'

  " Auto pairs
  Plug 'jiangmiao/auto-pairs'

  " gruvbox theme
  Plug 'morhetz/gruvbox'

  call plug#end()
endif
