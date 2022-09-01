source $HOME/.config/nvim/general/settings.vim
source $HOME/.config/nvim/vim-plug/plugins.vim
source $HOME/.config/nvim/keys/mappings.vim

" Start NERDTree and leave the cursor in it
autocmd VimEnter * NERDTree | wincmd p

" End NERDTree if file is closed
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

let g:loaded_python_provider = 0
