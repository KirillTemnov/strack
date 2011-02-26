###
Sources parser module
###
fs = require "fs"
path = require "path"
util = require "./util"

###
todo Add more languages for parsing
###
sourceOptions =
  js:
    oneLineComment: "//"
    multilineCommentStart: "/*"
    multilineCommentEnd: "*/"
    escapeStringQuotesRe: [/\\\'/g, /\\\"/g]
    stringRe: [new RegExp("'[^']+'", "g"), new RegExp('"[^"]+"', "g")]
  coffee:
    oneLineComment: "#"
    multilineCommentStart: "###"
    multilineCommentEnd: "###"
    escapeStringQuotesRe: [/\\\'/g, /\\\"/g]
    stringRe: [new RegExp("'[^']+'", "g"), new RegExp('"[^"]+"', "g")]

###
Remove strings from line

@param {String} line Source string
@param {Object} opts Language-specific options
@return {String} result Line without quoted strings
@api private
###
removeStringsFromLine = (line, opts) ->
  for re in opts.escapeStringQuotesRe
    line = line.replace re, ""
  for re in opts.stringRe
    line = line.replace re, ""
  line

###
Extract comments from line

@param {String} line Source string
@param {Object} opts Language-specific options
@param {Boolean} mlCommentOpen Flag, that set if multiline comment open in prevoius line
@return {Array} result Return array, that consist of comment string and new mlCommentOpen flag
@api public
###
extractCommentsText = (line, opts, mlCommentOpen) ->
  mlStart = line.indexOf opts.multilineCommentStart
  offset = if opts.multilineCommentStart == opts.multilineCommentEnd then 0 else mlStart + 1
  mlEnd = line.indexOf opts.multilineCommentEnd, offset
  olComment = line.indexOf opts.oneLineComment
  if mlCommentOpen
    if 0 <= mlEnd               # extract one line of multiline comment
      [line.substring(0, line.indexOf opts.multilineCommentEnd), false]
    else
      [line, true]
  else
    if 0 <= mlStart
      if mlStart < mlEnd        # extract one lined multiline comment
        [line.substring(mlStart + opts.multilineCommentStart.length, mlEnd), false]
      else                      # extract first line of multiline comment
        [line.substring(mlStart + opts.multilineCommentStart.length), true]
    else if 0 <= olComment
      [line.substring(olComment + opts.oneLineComment.length), false]
    else
      ["", false]
###
Add tickets from source file.
To all tickets add tags: +auto and +(filename.ext)

@param {String} file File path
@param {Array} tags State tags
@param {Object} tracker Tracker object
@param {Object} config Config object
@api public
###
exports.addTickets = (file, tags, tracker, config) ->
  opts = sourceOptions[path.extname(file).substring 1]
  if opts                       # parse file only if parsing options defined
    linesMax = parseInt config.get "maxlinesAfterState"
    linesMax ||= 3
    curLines = 1
    ticketText = ""
    fs.readFile file, (err, data) ->
      if null == err
        i = 0
        mlCommentOpen = false   # multiline comment open
        for line in data.toString().split "\n"
          # removeStringsFromLine for prevent search comments inside strings
          l = removeStringsFromLine line, opts
          [comment, mlCommentOpen] = extractCommentsText l, opts, mlCommentOpen
          i++
          for t in tags
            if 0 <= comment.toLowerCase().indexOf t
              if ticketText
                tracker.addUniqueTicket config, ticketText + "\n..."
                ticketText = ""
              else
                ticketText = comment.trim().replace(t, util.statePrefix + t) + " +auto +" +
                  path.basename(file) + "\n" + line
              curLines = 1
            else if ticketText
              if curLines < linesMax
                ticketText += "\n" + line
                curLines++
              else
                tracker.addUniqueTicket config, ticketText + "\n..."
                ticketText = ""
                curLines = 1


