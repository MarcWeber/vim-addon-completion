" set completfunc
command! -nargs=* CFComplete call vim_addon_completion#ChooseFuncWrapper('complete',<f-args>)

" set omnifunc
command! -nargs=* OFComplete call vim_addon_completion#ChooseFuncWrapper('omni',<f-args>)

inoremap <c-x><c-o> <c-r>=vim_addon_completion#SetFuncFirstTime('omni')."\<c-x>\<c-o>"<cr>
inoremap <c-x><c-u> <c-r>=vim_addon_completion#SetFuncFirstTime('complete')."\<c-x>\<c-u>"<cr>
