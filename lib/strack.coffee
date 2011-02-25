require "colors"
util = require "./util"
tracker = require "./tickets"
Tracker = tracker.Tracker
readline = require "readline"
fs = require "fs"
sys = require "sys"
usage = '''
Usage:

strack init
strack add
strack log
'''

# complete = (text) ->
# ##  console.log "text = #{text}"
#   if text == 'te'
#    process.stdout.write "test"
#   else
#     text

# eoi = ".."                      #end of input
# buf = ''
# run = (buffer) ->
#   buffer = buffer.toString()
#   if buffer == eoi
#     console.log buf
#     process.exit(0)
#   buf +=  buffer +  "\n"
#   repl.setPrompt "   "
#   repl.prompt()

#stdin  = process.openStdin()
#stdout = process.stdout
#repl = readline.createInterface stdin, stdout #, complete
# repl.setPrompt '-> '
# repl.on  'close',  ->  stdin.destroy()
# repl.on  'line',   run
# repl.prompt()
#

exports.run = ->
  config = new util.Config()
  tracker = new Tracker()
  tracker.load()


  switch process.argv[2]
    when "init"
      "clean Tracker"
      # fs.writeFileSync "strack.json", JSON.stringify issues
      # create file with tickets and id's
      # write files to .gitignore
    when "add", "a"
      # add new entry
      # first word may be a tag!
      if 3 < process.argv.length
        data = process.argv[3..]
        tracker.addTicket config, data.join " "
      else
        console.log "todo : promt to add ticket"
    when "config"
      key = process.argv[3] if 3 < process.argv.length
      if key
        value = process.argv[4] if 4 < process.argv.length
        if value
          param = {}
          param[key] = value
          config.update param
        else
          console.log "#{key} = #{config.get key}"
      else
        config.dump()

    when "log", "l"
      # log all or by tag (log + grep!)
      word = process.argv[3] if 3 < process.argv.length
      tracker.log word, config
    when "state", "s"
      if 4 < process.argv.length
        # replace state
        state = process.argv[3]
        id = process.argv[4]
        if 0 == id.indexOf util.statePrefix
          [state, id] = [id, state]
        tracker.changeState config, id, state
      else
        console.log "To change state add id and new state! "
    when "info", "i"
      if 3 < process.argv.length
        id = process.argv[3]
      else
        console.log "Add id for ticket "
    when "remove", "r", "rm"
      if 3 < process.argv.length
        ids = process.argv[3..]
        tracker.removeTickets ids
    when "comment", "c"
      id = process.argv[3] if 3 < process.argv.length
      comment = process.argv[4..].join " "if 4 < process.argv.length
      if !comment
        console.log "add comment!"
      else
         tracker.commentTicket config, id, comment

    else
      usage
