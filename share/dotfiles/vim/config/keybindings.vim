" ========================
" General keybindings
" ========================

" Better window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k

" Clear search highlight
nnoremap <leader>h :nohlsearch<CR>

" Save & quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Faster escape
inoremap jk <Esc>

" Better indenting
vnoremap < <gv
vnoremap > >gv

" Move lines
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
