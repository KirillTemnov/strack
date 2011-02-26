require "colors"
util = require "./util"
tracker = require "./tickets"
Tracker = tracker.Tracker
sys = require "sys"
parser = require "./source-parser"
usage = '''
Usage:

strack [COMMAND] args

strack commands and aliases:
  add, a\tAdd new ticket/task
  config\tWork with config options
  comment, c\tComment ticket/task
  help, h\tHelp on commands
  info, i\tShow info on ticket/task
  log, l\tShow tracker log.
        \tSearch by tags, states and regular words
  remove, rm\tRemove ticket/task
  state, s\tChange ticket/task state
  fs    \tSearch tags in source
'''

showHelp = ->
  switch process.argv[3]
    when "add"
      console.log "strack add [ticket/task text]\n\n  Add new ticket/task\n  For input multiline text, omit all parameters after add\n"
    when "config"
      console.log "strack config [key [value]]\n\n  Work with config options\n  If key and value omited, show all config params\n" +
        "  If key is set, show key value\n  If key and value is set, write new value to config\n\nConfig options:\n" +
        '  user\t\t\tUser name\n  email\t\t\tUser email\n  log\t\t\tLog format, one of "tiny", "short", "long"\n  showDonedTasks\tShow done tasks' +
        ' when watch log, one of "true", "false"\n  verbose\t\tSet/unset verbose mode, one of "true", "false"\n'
    when "comment"
      console.log "strack comment id [comment]\n\n  Comment ticket/task\n  For input multiline comment, omit comment parameter\n"
    when "info"
      console.log "strack info id\n\n  Show detail information about ticket/task\n"
    when "log"
      console.log "strack log [pattern]\n\n  Show tracker log\n  If pattern is set, only tasks, that match this pattern will be displayed\n"
    when "remove"
      console.log "strack remove id [id2, id3...]\n\n  Remove tickets/tasks from tracker\n"
    when "state"
      console.log "strack state id new-state\n\n  Change state of ticket/task\n"
    when "fs"
      console.log "strack ld [ext [keywords]]\n\n  Search keywords in file with ext " +
        'extension\n  Default ext is "js"\n  Default keywords is [config.defaultState]\n'
    else
      console.log usage

exports.run = ->
  config = new util.Config()
  tracker = new Tracker()
  tracker.load()


  switch process.argv[2]
    when "init"
      "clean Tracker"
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
        tracker.info id, config
      else
        console.log "Add id for ticket "
    when "remove", "r", "rm"
      if 3 < process.argv.length
        ids = process.argv[3..]
        tracker.removeTickets ids
    when "comment", "c"
      id = process.argv[3] if 3 < process.argv.length
      if id
        comment = process.argv[4..].join " "if 4 < process.argv.length
        if !comment
          util.readText config.get("eof"), (comment) ->
            tracker.commentTicket config, id, comment
        else
           tracker.commentTicket config, id, comment
      else
        console.log "Ticket id is missing"
    when "help", "h"
      showHelp()
    when "fs"                   #from source
      ext = "." + if 3 < process.argv.length then process.argv[3].toLowerCase() else "js"
      tags =  if 4 < process.argv.length then process.argv[4..] else [config.get "defaultState"]
      filteredTags = []
      tags.forEach (tag) -> filteredTags.push tag.toLowerCase()
      util.listDir(process.cwd(), ext).forEach (file) -> parser.addTickets file, tags, tracker, config

    else
      console.log usage
