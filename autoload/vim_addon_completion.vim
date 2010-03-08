if !exists('g:completion_function_config') | let g:completion_function_config = {} | endif
let s:config = g:completion_function_config

" last_chosen keep a list of names so that when you enter a different buffer
" having same filetype the same comcpletion func can be assigned
let s:config['last_chosen'] = get(s:config, 'last_chosen', {})
let s:config['functions'] = get(s:config, 'functions', {})
let s:last_chosen = s:config['last_chosen']

" opts: dict with keys
"             'type': "omni" or "complete"
"   optional: 'regex':   Only show items matching regex
"   optional: 'user' : any_val Function was called by user (update dict last_chosen)
fun! vim_addon_completion#ChooseFunc(opts)

  let items = values(s:config['functions'])
  " filter by filetype
  call filter(items, '!has_key(v:val,"scope") || v:val["scope"] =~ '.string(substitute(&filetype,'\.','\|','g')))
  " filter by given regex or name:
  if has_key(a:opts,'regex')
    let regex = a:1
    call filter(items, 'v:val["func"] =~ '.string(a:opts['regex']))
  endif

  " let user choose an item if there are more than 1 left:
  if len(items) > 1
    let list = []
    for i in items
      call add(list, i['func'].' '.get(i,'scope','').' '.get(i,'description',''))
    endfor
    let idx = tlib#input#List("si",'choose '.a:opts['type'].'func: ', list) - 1
    let items = [items[idx]]
  endif
  if len(items) == 0
    echoe "no completion functions available!"
    return
  else
    let item = items[0]
    if &filetype != '' && has_key(a:opts,'user')
      let s:last_chosen[&filetype] = item['func']
    endif

    call vim_addon_completion#SetCompletionFunc(i['func'])
  endif
endf

fun! vim_addon_completion#SetCompletionFunc(func)
  let i = s:config['functions'][a:func]
  " be smart: If the current completion function isn't known save that
  " the user can switch back
  exec 'let fu = &'.a:opts['type'].'func'
  if fu != '' && !has_key(s:config['functions'], fu)
    let d = {'func' : fu}
    if &filetype != ''
      let d['scope'] = &filetype
    end
    call vim_addon_completion#RegisterCompletionFunc(d)
  endif

  " set oompletion function
  exec 'set '.a:opts['type'].'func='.i['func']
  if has_key(i,'completeopt')
    exec 'set completeopt='.i['completeopt']
  endif
endf

fun! vim_addon_completion#ChooseFuncWrapper(type, ...)
  let dict = {'user' : 1, 'type': a:type}
  if a:0 > 0
    let dict['regex'] = a:1
  endif
  call vim_addon_completion#ChooseFunc(dict)
endf

fun! vim_addon_completion#Var()
  call scriptmanager#DefineAndBind('res', a:scope.':completion_functions', '{}')
  return res
endf

" scope either g or b which means global or buffer
" dict has keys:
"   func: string. This is called
"   description: long description (optional)
"   scope: filetype. This function will only be shown selecting a completion
"         function when editing that filetype
"   completeopt: complete options
"
fun! vim_addon_completion#RegisterCompletionFunc(dict)
  let s:config['functions'][a:dict['func']] = a:dict
endf

" if no function is set set one
fun! vim_addon_completion#SetFuncFirstTime(type)
  let v = a:type.'func'
  exec 'let fun = &'.v
  if fun == ''
    call vim_addon_completion#ChooseFunc({'user' : 1, 'type': a:type})
  endif
  return ''
endf
