if exists("g:testerical_loaded")
  finish
endif

noremap <unique> <Plug>(testerical-run-individual) 
  :<C-u>call testerical#run_indiviual(1)<Return>
noremap <unique> <Plug>(testerical-run-file)
  :<C-u>call testerical#run_file(2)<Return>
noremap <unique> <Plug>(testerical-run-last) 
  :<C-u>call testerical#run_last()<Return>

if !hasmapto('<Plug>(testerical-run-individual)')
  map <unique> <Leader>rt <Plug>(testerical-run-individual)
endif
if !hasmapto('<Plug>(testerical-run-file)')
  map <unique> <Leader>rf <Plug>(testerical-run-file)
endif
if !hasmapto('<Plug>(testerical-run-last)')
  map <unique> <Leader>rl <Plug>(testerical-run-last)
endif

let g:testerical_loaded = 1
