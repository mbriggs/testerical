function! testerical#run_with_test_scope(scope)
  call s:load_settings()

  if !s:is_testable()
    echo "This file doesn't contain ruby test(s)."
  else
    if !s:is_testable()
      return
    endif

    let s:test_scope = a:scope
    call s:test_patterns[s:pattern]()
  endif
endfunction

function! testerical#run_last()
  call s:load_settings()
  if !exists("g:testerical_last_cmd")
    echo "No previous test has been run"
  else
    call s:execute_and_redirect(g:testerical_last_cmd)
  end
endfunction

function! s:test_case_for_pattern(patterns)
  let ln = a:firstline
  while ln > 0
    let line = getline(ln)
    for pattern in keys(a:patterns)
      if line =~ pattern
        if s:pattern == 'spec'
          return a:patterns[pattern](ln)
        else
          return a:patterns[pattern](line)
        endif
      endif
    endfor
    let ln -= 1
  endwhile
  return 'false'
endfunction

function! s:escape_backslash(str)
  return substitute(a:str, '\', '\\\\', 'g')
endfunction

function! s:execute_and_redirect(cmd)
  let g:testerical_last_cmd = a:cmd

  let s:old_errorformat = &errorformat
  let s:old_errorfile = &errorfile
  let &errorformat = s:errorformat . s:errorformat_backtrace . ',' . s:errorformat_ruby . ',' . s:old_errorformat . ',%-G%.%#'
  let &errorfile = g:testerical_log_file

  if g:testerical_in_quickfix > 0
    silent execute "!" . a:cmd . " | tee " . g:testerical_log_file  
  else
    silent execute "!" . a:cmd . " &> " . g:testerical_log_file . " &"
  endif

  let s:relativize_absolute_test_paths = '!sed -i -e "s/^\(\s*\)\//\1/g" ' . g:testerical_log_file
  silent execute s:relativize_absolute_test_paths

  redraw!

  if g:testerical_in_quickfix > 0
    cfile
    cw
  endif

  " let &errorformat = s:old_errorformat
  " let &errorfile = s:old_errorfile
endfunction

function! s:run_test()
  call s:load_settings()

  if s:test_scope == 1
    let cmd = g:testerical_cmd_testcase . " -v"
  elseif s:test_scope == 2
    let cmd = g:testerical_cmd_test
  end

  let case = s:test_case_for_pattern(s:test_case_patterns['test'])
  if s:test_scope == 2 || case != 'false'
    let case = substitute(case, "'\\|\"", '.', 'g')
    let cmd = substitute(cmd, '%c', case, '')
    let cmd = substitute(cmd, '%p', s:escape_backslash(@%), '')

    if @% =~ '^test'
      let cmd = substitute(cmd, '^ruby ', 'ruby -Itest -rtest_helper ', '')
    endif

    call s:execute_and_redirect(cmd)
  else
    echo 'No test case found.'
  endif
endfunction

function! s:run_spec()
  if s:test_scope == 1
    let cmd = g:testerical_cmd_example
  elseif s:test_scope == 2
    let cmd = g:testerical_cmd_spec
  endif

  if g:testerical_spec_drb > 0
    let cmd = cmd . " --drb"
  endif

  let case = s:test_case_for_pattern(s:test_case_patterns['spec'])
  if s:test_scope == 2 || case != 'false'
    let cmd = substitute(cmd, '%c', case, '')
    let cmd = substitute(cmd, '%p', s:escape_backslash(@%), '')
    call s:execute_and_redirect(cmd)
  else
    echo 'No spec found.'
  endif
endfunction

function! s:run_feature()
  let s:old_in_quickfix = g:testerical_in_quickfix
  let g:testerical_in_quickfix = 0

  if s:test_scope == 1
    let cmd = g:testerical_cmd_story
  elseif s:test_scope == 2
    let cmd = g:testerical_cmd_feature
  endif

  let case = s:test_case_for_pattern(s:test_case_patterns['feature'])
  if s:test_scope == 2 || case != 'false'
    let cmd = substitute(cmd, '%c', case, '')
    let cmd = substitute(cmd, '%p', s:escape_backslash(@%), '')
    call s:execute_and_redirect(cmd)
  else
    echo 'No story found.'
  endif

  let g:testerical_in_quickfix = s:old_in_quickfix
endfunction

let s:test_patterns = {}
let s:test_patterns['test'] = function('s:run_test')
let s:test_patterns['spec'] = function('s:run_spec')
let s:test_patterns['\.feature$'] = function('s:run_feature')

function! s:test_case_with_index_1(str)
  return split(a:str)[1]
endfunction

function! s:test_case_with_index_2(str)
  return "test_" . join(split(split(a:str, '"')[1]), '_')
endfunction

function! s:test_case_with_index_3(str)
  return split(a:str, '"')[1]
endfunction

function! s:test_case_with_index_4(str)
  return "test_" . join(split(split(a:str, "'")[1]), '_')
endfunction

function! s:test_case_with_index_5(str)
  return split(a:str, "'")[1]
endfunction

function! s:spec_line_for(str)
  return a:str
endfunction

function! s:story_line_for(str)
  return join(split(split(a:str, "Scenario:")[1]))
endfunction

let s:test_case_patterns = {}
let s:test_case_patterns['test'] = {'^\s*def test':function('s:test_case_with_index_1'), '^\s*test \s*"':function('s:test_case_with_index_2'), "^\\s*test \\s*'":function('s:test_case_with_index_4'), '^\s*should \s*"':function('s:test_case_with_index_3'), "^\\s*should \\s*'":function('s:test_case_with_index_5')}
let s:test_case_patterns['spec'] = {'^\s*\(it\|example\|describe\|context\) \s*':function('s:spec_line_for')}
let s:test_case_patterns['feature'] = {'^\s*Scenario:':function('s:story_line_for')}

function! s:is_testable()
  for pattern in keys(s:test_patterns)
    if @% =~ pattern
      let s:pattern = pattern
      return 1
    endif
  endfor
endfunction

function! s:load_settings()
  if !exists("g:testerical_in_quickfix")
    let g:testerical_in_quickfix = 0
  endif
  if !exists("g:testerical_in_spork")
    let g:testerical_in_spork = 0
  endif
  if g:testerical_in_spork > 0
    let g:testerical_cmd_testcase = "testdrb -Itest %p -n '/%c/'"
    let g:testerical_cmd_test = "testdrb -Itest %p"
  endif
  if !exists("g:testerical_spec_drb")
    let g:testerical_spec_drb = 0
  endif
  if !exists("g:testerical_cmd_test")
    let g:testerical_cmd_test = "ruby %p"
  endif
  if !exists("g:testerical_cmd_testcase")
    let g:testerical_cmd_testcase = "ruby %p -n '/%c/'"
  endif
  if !exists("g:testerical_cmd_spec")
    let g:testerical_cmd_spec = "rspec %p"
  endif
  if !exists("g:testerical_cmd_example")
    let g:testerical_cmd_example = "rspec %p -l %c"
  endif
  if !exists("g:testerical_cmd_feature")
    let g:testerical_cmd_feature = "cucumber %p"
  endif
  if !exists("g:testerical_cmd_story")
    let g:testerical_cmd_story = "cucumber %p -n '%c'"
  endif
  if !exists("g:testerical_log_file")
    let g:testerical_log_file = "/tmp/vim.log"
  endif
  if !filewritable(g:testerical_log_file)
    silent execute "!touch " . g:testerical_log_file | redraw!
  endif
endfunction

let s:errorformat='%A%\\d%\\+)%.%#,'

" current directory
let s:errorformat=s:errorformat . '%D(in\ %f),'

" failure and error headers, start a multiline message
let s:errorformat=s:errorformat
      \.'%A\ %\\+%\\d%\\+)\ Failure:,'
      \.'%A\ %\\+%\\d%\\+)\ Error:,'
      \.'%+A'."'".'%.%#'."'".'\ FAILED,'

" exclusions
let s:errorformat=s:errorformat
      \.'%C%.%#(eval)%.%#,'
      \.'%C-e:%.%#,'
      \.'%C%.%#/lib/gems/%\\d.%\\d/gems/%.%#,'
      \.'%C%.%#/lib/ruby/%\\d.%\\d/%.%#,'
      \.'%C%.%#/vendor/rails/%.%#,'

" specific to template errors
let s:errorformat=s:errorformat
      \.'%C\ %\\+On\ line\ #%l\ of\ %f,'
      \.'%CActionView::TemplateError:\ compile\ error,'

" stack backtrace is in brackets. if multiple lines, it starts on a new line.
let s:errorformat=s:errorformat
      \.'%Ctest_%.%#(%.%#):%#,'
      \.'%C%.%#\ [%f:%l]:,'
      \.'%C\ \ \ \ [%f:%l:%.%#,'
      \.'%C\ \ \ \ %f:%l:%.%#,'
      \.'%C\ \ \ \ \ %f:%l:%.%#]:,'
      \.'%C\ \ \ \ \ %f:%l:%.%#,'

" catch all
let s:errorformat=s:errorformat
      \.'%Z%f:%l:\ %#%m,'
      \.'%Z%f:%l:,'
      \.'%C%m,'

" syntax errors in the test itself
let s:errorformat=s:errorformat
      \.'%.%#.rb:%\\d%\\+:in\ `load'."'".':\ %f:%l:\ syntax\ error\\\, %m,'
      \.'%.%#.rb:%\\d%\\+:in\ `load'."'".':\ %f:%l:\ %m,'

" and required files
let s:errorformat=s:errorformat
      \.'%.%#:in\ `require'."'".':in\ `require'."'".':\ %f:%l:\ syntax\ error\\\, %m,'
      \.'%.%#:in\ `require'."'".':in\ `require'."'".':\ %f:%l:\ %m,'

" exclusions
let s:errorformat=s:errorformat
      \.'%-G%.%#/lib/gems/%\\d.%\\d/gems/%.%#,'
      \.'%-G%.%#/lib/ruby/%\\d.%\\d/%.%#,'
      \.'%-G%.%#/vendor/rails/%.%#,'
      \.'%-G%.%#%\\d%\\d:%\\d%\\d:%\\d%\\d%.%#,'

" final catch all for one line errors
let s:errorformat=s:errorformat
      \.'%-G%\\s%#from\ %.%#,'
      \.'%f:%l:\ %#%m,'

let s:errorformat_backtrace='%D(in\ %f),'
      \.'%\\s%#from\ %f:%l:%m,'
      \.'%\\s%#from\ %f:%l:,'
      \.'%\\s#{RAILS_ROOT}/%f:%l:\ %#%m,'
      \.'%\\s%#[%f:%l:\ %#%m,'
      \.'%\\s%#%f:%l:\ %#%m,'
      \.'%\\s%#%f:%l:,'
      \.'%m\ [%f:%l]:'

let s:errorformat_ruby='\%-E-e:%.%#,\%+E%f:%l:\ parse\ error,%W%f:%l:\ warning:\ %m,%E%f:%l:in\ %*[^:]:\ %m,%E%f:%l:\ %m,%-C%\tfrom\ %f:%l:in\ %.%#,%-Z%\tfrom\ %f:%l,%-Z%p^'

