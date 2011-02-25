require "colors"
util = require "./util"
tracker = require "./tickets"
Tracker = tracker.Tracker
fs = require "fs"
sys = require "sys"
usage = '''
Usage:

strack [COMMAND] args

strack commands and aliases:
  add, a\tAdd new ticket/task
  log, l\tShow tracker log.
        \tSearch by tags, states and regular words
  config\tWork with config options
  state, s\tChange ticket/task state
  info, i\tShow info on ticket/task
  remove, rm\tRemove ticket/task
  comment, c\tComment ticket/task
  help, h\tHelp on commands

'''

showHelp = ->


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
      if 3 < process.argv.length
        data = process.argv[3..]
        tracker.addTicket config, data.join " "
      else
        util.readText config.get("eof"), (data) ->
          tracker.addTicket config, data
    when "config"
      key = process.argv[3] if 3 < process.argv.length
      if key
        value = process.argv[4] if 4 < process.argv.length
        if value                # set new value
          param = {}
          param[key] = value
          config.update param
        else                    # show key value
          console.log "#{key} = #{config.get key}"
      else                      # dump all settings
        config.dump()
    when "log", "l" # log all or by tag (log + grep!)
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
        tracker.info id
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
        util.readText config.get("eof"), (comment) ->
          tracker.commentTicket config, id, comment
      else
         tracker.commentTicket config, id, comment
    when "help", "h"
      showHelp()
    else
      console.log usage
