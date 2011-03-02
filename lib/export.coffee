###
Module for export project files
###

fs = require "fs"
util = require "./util"

###
Export tracker to txt file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toTxt = (tracker, filename) ->
  out = "#{tracker.name}\n"
  for k,t of tracker.tickets
    out += "created: #{t.created}"
    out += "\tmodified: #{t.modified}" if t.created != t.modified
    out += "\n#{t.author.user} <#{t.author.email}>\n#{t.text}\n"
    out += "Comments :\n" if 0 < t.comments.length
    for c in t.comments
      out += "#{c.author}:\n#{c.comment}\n"
    out += "\n"
  fs.writeFileSync filename, out

###
Export tracker to org-mode file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toOrg = (tracker, filename) ->
  out = "#+STARTUP: hidestars\n#+STARTUP: align\n#+SEQ_TODO:"
  tracker.states.initial.forEach (state) -> out += "#{state.toUpperCase()} "
  out += "| "
  tracker.states.final.forEach (state) -> out += "#{state.toUpperCase()} "
  out += "\n#+AUTHOR: #{tracker.config.get 'user'}\n#+EMAIL: #{tracker.config.get 'email'}\n"
  out +="\n\n* #{tracker.name || tracker.config.get('user') + '\'s project'}[/]\n"
  for t in tracker._sortTickets()
    [text, tags] = util.searchAndRemoveTags t.text, ""
    text = text.replace('@' + t.state, '').replace /\n/g, '\n   '
    tags = tags.join(":").replace(/[\-\.]/g, "")
    tags = ":#{tags}:" if tags
    out += "** #{t.state.toUpperCase()} " + "#{text.replace '\n', tags + '\n'}"
    if 0 < t.comments.length
      out += "*** Comments\n"
      for c in t.comments
        out += "    - #{c.comment.replace /\n/g, '\n     '}\n"
    out += "\n"
  fs.writeFileSync filename, out

###
Export tracker to html file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toHtml = (tracker, filename) ->
  "export to html"