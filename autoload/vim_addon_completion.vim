" provide a function which translates a pattern into a regex and or glob
" pattern. You can implement camel case matching this way.
"
" may return {}
" if vim_regex is returned this pattern should be matched against names as
" well to determine wether an item must be added to the completion list
" users can implement camel case matching or similar
" identifier: a name of the completion invoking this function.
"             You may want to customize only some completions, not all
"
fun! vim_addon_completion#AdditionalCompletionMatchPatterns(pat, identifier, ...)
  let opts = a:0 > 0 ? a:1 : {}
  let start = get(opts,'match_beginning_of_string', 1)

  if exists('g:vim_addon_completion_Pattern_To')
    return call(g:vim_addon_completion_Pattern_To, [a:pat, a:identifier, opts])
  else
    " default: provide camel case matching
    " don't know how to make CamelCase matching using glob
    " glob may be used by some plugins
    return {
          \ 'vim_regex': (start ? '^' : '').vim_addon_completion#AdvancedCamelCaseMatching(a:pat)
          \ }
  endif
endf

" abc also matches axxx_bxxx_cxxx
" ABC also matches AxxxBxxxxCxxx
" ABC also matches ABxxCxx
function! vim_addon_completion#AdvancedCamelCaseMatching(expr)
  let result = ''
  if len(a:expr) > 5 " vim can't cope with to many \( ? and propably we no longer want this anyway
    return 'noMatchDoh'
  endif
  for index in range(0,len(a:expr))
    let c = a:expr[index]
    if c =~ '\u'
      let result .= c.'\u*\l*_\='
    elseif c =~ '\l'
      let result .= c.'\l*\%(\l\)\@!_\='
    else
      let result .= c
    endif
  endfor
  return result
endfunction

" same as ctrl-n but smarter because its using AdvancedCamelCaseMatching
" or more dump because its only taking the current buffer into acocunt
" only complete vars which are longer than 3 chars.
fun! vim_addon_completion#CompleteWordsInBuffer(findstart, base)
  if a:findstart
    let [bc,ac] = vim_addon_completion#BcAc()
    let s:match_text = matchstr(bc, '\zs[^\t#$,().&[\]/{}\''`";: ]*$')
    let s:start = len(bc)-len(s:match_text)
    return s:start
  else
    
    let words = {}
    for w in split(join(getline(1, line('$'))," "),'[/#$,''"`; \&()[\t\]{}.,+*:]\+')
      let words[w] = 1
    endfor

    let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(a:base
        \ , "ocaml_completion", { 'match_beginning_of_string': 1})
    let additional_regex = get(patterns, 'vim_regex', "")

    let r = []
    for t in keys(words)
      if len(t) >= 4
        if t =~ '^'.a:base || (additional_regex != '' && t =~ additional_regex)
          call add(r, {'word': t})
        endif
      endif
    endfor
    return r
  endif
endf

" before cursor after cursor
function! vim_addon_completion#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

" complete with custom function preserving omnifunc setting
" Usage: inoremap <buffer> <expr> \start_completion vim_addon_completien#CompleteWith("vim_addon_completion#CompleteWordsInBuffer")'
fun! vim_addon_completion#CompleteUsing(fun, ...)
  let co = a:0 > 0 ? a:1 : &l:completeopt
  " after this characters have been process reset completion function.
  " feedkeys must be used, returning same chars with return will hide the
  " completion menue.
  call feedkeys("\<C-r>=['', setbufvar('%', '&omnifunc', ".string(&l:omnifunc)."), setbufvar('%', '&completeopt', ".string(&l:completeopt).")][0]\<cr>",'t')
  let &l:omnifunc=a:fun
  let &l:completeopt = co
  return "\<C-x>\<C-o>"
endf

" Usage:
" plugin file:
" if !exists('g:vim_haxe') | let g:vim_haxe = {} | endif | let s:c = g:vim_haxe
" let s:c.complete_lhs_haxe = get(s:c, 'complete_lhs_haxe', '<c-x><c-o>')
" let s:c.complete_lhs_tags = get(s:c, 'complete_lhs_tags', '<c-x><c-u>')
"
" ftplugin or au command:
" if !exists('g:vim_haxe') | let g:vim_haxe = {} | endif | let s:c = g:vim_haxe
" vim_addon_completion#InoremapCompletions(s:c, [
" \ { 'setting_keys' : ['complete_lhs_haxe'], 'fun': 'haxe#CompleteHAXE'},
" \ { 'setting_keys' : ['complete_lhs_tags'], 'fun': 'haxe#CompleteClassNames'}
" \ ] )
" key_suffix is optional
"
" Description: user completion settings are taken from a:settings using
" keys complete_lhs{suffix} and complete_opts{suffix}
" defining completion functions using vim_addon_completion#CompleteUsing
" which restores omnifunc setting.
fun! vim_addon_completion#InoremapCompletions(settings, list)
  for i in a:list
    let key_suffix = get(i,'key_suffix','')
    let lhs_key = i.setting_keys[0]
    let opt_key = get(i.setting_keys, 1, substitute(lhs_key, '_lhs\>','_opts',''))
    let lhs = a:settings[lhs_key]
    if empty(lhs)
      throw "bad lhs setting for ".lhs_key
    endif

    if mapcheck(lhs, 'i') || (!empty(&l:omnifunc) && lhs == "<c-x><c-o>") || (!empty(&l:completefunc) && lhs == "<c-x><c-u>")
      echom "warning: completion collision for ".lhs_key.' on '. lhs .'. Consider overwriting lhs in your .vimrc. See vim-addon-completion and the plugin having default lhs '.lhs
    else
      let completeopts = get(a:settings, opt_key, "preview,menu,menuone")
        exec 'inoremap <buffer> <expr> '.lhs
              \ .' vim_addon_completion#CompleteUsing('.string(i.fun).','.string(completeopts).')'
      endif
  endfor
endf
