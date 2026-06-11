" ========================
" Gruvbox theme
" ========================

set background=dark

" Recommended settings for gruvbox
let g:gruvbox_contrast_dark = 'medium'
let g:gruvbox_italic = 1
let g:gruvbox_bold = 1

" gruvbox ships as a plugin, so apply it only when it is installed. `silent!`
" keeps a fresh, plugin-less install (offline, or before :PlugInstall runs)
" from aborting startup with E185.
silent! colorscheme gruvbox

" ========================
" UI tweaks
" ========================

set termguicolors
set laststatus=2
set showmode

" Transparent background (optional)
highlight Normal ctermbg=NONE guibg=NONE
highlight NonText ctermbg=NONE guibg=NONE
