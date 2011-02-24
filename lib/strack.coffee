require "colors"
util = require "./util"
readline = require "readline"

usage = '''
Usage:

strack init
strack add
strack log
'''

complete = (text) ->
##  console.log "text = #{text}"
  if text == 'te'
   process.stdout.write "test"
  else
    text

eoi = ".."                      #end of input
buf = ''
run = (buffer) ->
  buffer = buffer.toString()
  if buffer == eoi
    console.log buf
    process.exit(0)
  buf +=  buffer +  "\n"
  repl.setPrompt "   "
  repl.prompt()

#stdin  = process.openStdin()
#stdout = process.stdout
#repl = readline.createInterface stdin, stdout #, complete
# repl.setPrompt '-> '
# repl.on  'close',  ->  stdin.destroy()
# repl.on  'line',   run
# repl.prompt()
#




tags: "bug", "done", "todo", "issue", "message", "wiki"

issues = {}

switch process.argv[2]
  when "init"
    console.log "INIT"
    # create file with issues and id's
    # write files to .gitignore
  when "add", "a"
    # add new entry
    # first word may be a tag!
    if process.argv.length > 3
      data = process.argv[3..]
      console.log "ADD: #{data}"
    else
      # promt to add issue
  when "log", "l"
    # log all or by tag (log + grep!)
    console.log "LOG!"
  else
    console.log usage
