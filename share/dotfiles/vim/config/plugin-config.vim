" ========================
" NERDTree
" ========================
nnoremap <leader>e :NERDTreeToggle<CR>

let g:NERDTreeShowHidden = 1

" ========================
" FZF
" ========================
nnoremap <leader>f :Files<CR>
nnoremap <leader>g :GFiles<CR>
nnoremap <leader>b :Buffers<CR>

" ========================
" Lightline
" ========================
let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ }

" ========================
" Vim Fugitive
" ========================
nnoremap <leader>gs :Git<CR>

" ========================
" Commentary
" ========================
" (no config needed, but kept for clarity)
"
