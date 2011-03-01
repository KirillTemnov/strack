###
Module for export project files
###

fs = require "fs"

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
  "export to org"

###
Export tracker to html file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toHtml = (tracker, filename) ->
  "export to html"