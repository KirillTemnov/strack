require "colors"
crypto = require "crypto"
signType = "md5"
fs = require "fs"
readline = require "readline"
p = require "path"
home = process.env.HOME + "/"
exports.maxWidth = 100          # todo use this
sys = require "sys"             # todo remove on release

# prefix for states, e.g. @todo, @done
exports.statePrefix = statePrefix = "@"
# prefix for tags, e.g. +javascript, coffee-script
exports.tagPrefix = tagPrefix = "+"

stateRe = new RegExp "^@(\\S+)"
tagRe = new RegExp "^\\+(\\S+)"
separatorCharsRe =  new RegExp "([^:,.+\\-!@#&=]+)"

###
Create hash from string

@param {String} str Source string
@return {String} hash Hex digest hash
@api public
###
exports.createHash = createHash = (str, secret="change me") ->
  crypto.createHmac(signType, secret).update(str).digest("hex")

###
Create unique ID for string

@param {String} str Source string
@return {String} hash Unique hex digest hash
@api public
###
exports.createId = createId = (str, config=null) ->
  secret = if config then config.get "secret" else "change me"
  createHash str + new Date(), secret

###
Class for set or set config flags
###
class Config
  ###
  Load config. Loads config from ~/.strack
  If config file not exists, create it.
  Try to gather user name and email from ~/.gitconfig, if
  file not exists, get user from process.env.USER

  @return {Object} config Config object, that have "user" and "email" keys.
  @api public
  ###
  constructor: ->
    try
      @configFile = home + ".strack"
      fs.statSync @configFile
      @config = JSON.parse fs.readFileSync @configFile
      @_writeDefaults()
    catch err
      if 'ENOENT' == err.code
        @config = {}
        try
          gitconfig = home + ".gitconfig"
          fs.statSync gitconfig
          conf = fs.readFileSync gitconfig
          for line in conf.toString().split "\n"
            line = line.trim()
            if 0 == line.indexOf "name"
              @config.user = line.split("=")[1].trim()
            else if 0 == line.indexOf "email"
              @config.email = line.split("=")[1].trim()
        catch err2
          @config.user = config.user
          @config.email = config.email ||  ""
          @_writeDefaults()
        fs.writeFileSync @configFile,  JSON.stringify @config
      else
        throw err

  ###
  Write defaults to config in they not presents

  @api private
  ###
  _writeDefaults: ->
    @config.user ||= process.env.USER
    if ! @config.email
      console.warn "User email not set!, please add email by executing\nstrack cf email ".red +
      "your@email.here".red

    @config.log ||= "short"                  # log format. one of "tiny", "short", "long"
    @config.secret ||= createId @config.user # secret key for generate hash values
    @config.defaultState ||= "todo"          # default state
    @config.showDone ||= "false"             # show done tasks
    @config.eof ||= ".."                     # end of file, when add/edit multiline text
    @config.verbose || = "true"              # verbose mode
    @config.maxlinesAfterState ||= "3"       # max lines, that read after founded state in
                                             # source files, when auto search todo performs
    @config.sortOrder ||= "asc"              # sort order: "asc" or "desc"
    @config.showLineNumbers ||= "true"       # show line numbers when edit multiline text
    @config.trackerFile ||= ".strack"        # tracker file name
    @config.askBeforeCreate ||= "yes"        # ask before create new tracker

  ###
  Update config with params

  @param {Object} params New config params
  @api public
  ###
  update: (params={}) ->
    for k,v of params
      @config[k] = v
    fs.writeFileSync @configFile,  JSON.stringify @config

  ###
  Dump all config to console

  @api public
  ###
  dump: ->
    console.log "Config parameters:"
    for k,v of @config
      console.log "#{k} = #{v}"

  ###
  Get config key

  @param {String} key Config key
  @api public
  ###
  get: (key) ->
    @config[key]

  ###
  Set config key

  @param {String} key Config key
  @param {String} value Value for key
  @api public
  ###
  set: (key, value) ->
    @config[key] = value

  ###
  Make user dictionary from object

  @return {Object} userDict Dictionary, containing only keys "email" and "user"
  @api public
  ###
  makeUserDict: ->
    user: @config.user, email: @config.email

exports.Config = Config


###
Parse text and return it tags and comments

###
exports.parseText = parseText = (text) ->
  r =
    states: []
    tags: []
  for word in text.split " "
    if 0 == word.indexOf statePrefix
      r.states.push word.substring 1
    else if 0 == word.indexOf tagPrefix
      r.tags.push word.substring 1
  r

###
Get state from text.

@param {String} text Text for search state
@param {String} config Config object
@return {String} state If text have no states, return defaultState
@api public
###
exports.getState = (text, config) ->
  for word in text.split " "
    if 0 == word.indexOf statePrefix
      return word.substring 1
  config.get "defaultState"

###
Replace state from one to another

@param {String} text Text with one state
@param {String} newState New state value
###
exports.replaceState = (text, newState) ->
  r = []
  for word in text.split " "
    if 0 == word.indexOf statePrefix
      r.push newState
    else
      r.push word
  r.join " "

###
Get word if it matching regexp

@param {String} word Analized word
@param {RegExp} re Regular expression for match
@param {Number} prefixLen Prefix length (for get substring of matching text)
@return {Array|null} result If word match re, return Array of matching part and rest of word.
                            Else, if word not match re, function returns null
@api private
###
getWord = (word, re, prefixLen=1) ->
  m = word.match re
  if m
    word2 = word.substring prefixLen
    m2 = word2.match separatorCharsRe
    if m2
      return [m2[1], word2.substring m2[0].length]
  null

###
Push word to result and if makeGrey flag is true, word become grey

@param {Array} result Accumulator array for words
@param {String} uninflectedWord Word that pad to second word to the left
@param {String} word Word string
@param {Boolean} makeGrey Flag, that points to change word color
@api private
###
pushWords = (result, uninflectedWord, word, makeGrey) ->
  result.push  uninflectedWord + if makeGrey then word.grey else word

###
Apply color or style on text

@param {String} text Text to apply color
@param {String|Array} color Color can be a string or a list of strings
@return {String} coloredText Text with applyed color
@api private
###
applyColor = (text, color) ->
  switch color
    when "black"
      text.black
    when "white"
      text.white
    when "magenta"
      text.magenta
    when "blue"
      text.blue
    when "green"
      text.green
    when "grey"
      text.grey
    when "yellow"
      text.yellow
    when "red"
      text.red
    when "underline"
      text.underline
    when "bold"
      text.bold
    when "italic"
      text.italic
    when "inverse"
      text.inverse
    else
      if "object" == typeof color
        for c in color
          text = applyColor text, c
        c
      text

###
Colorize string.

@param {String} str Source string
@param {Boolean} flag Color flag
@param {String|Array} trueColor Color(s), that applied if flag is set to true
@param {String|Array} falseColor Color(s), that applied if flag is set to false
@return {String} result Resulting string
@api public
###
exports.colorizeString = (str, flag, trueColor="green", falseColor="grey") ->
  applyColor  str, if flag then trueColor else falseColor


###
Colorize text for output to terminal.

@param {String} text Text to colorize
@param {String} pattern Search pattern, default - null
@param {Boolean} done Flag, that signal that text must be grey (if done = true)
@return {String} Colored string
@api public
###
exports.colorizeText = (text, matchingPattern=null, done=false) ->
  result = []
  for word in text.split(" ")
    uninflectedWord = ""
    if 0 == word.indexOf statePrefix
      words = getWord word, stateRe, statePrefix.length
      if words
        uninflectedWord = words[0].bold.underline.green
        uninflectedWord = uninflectedWord.inverse if done
        word =  words[1]
    else if 0 == word.indexOf tagPrefix
      words = getWord word, tagRe, tagPrefix.length
      if words
        uninflectedWord = words[0].underline.magenta
        word = words[1]
    else if 0 <= word.indexOf matchingPattern
      wrd = word.substring 0, matchingPattern.length
      wrd = wrd.bold.red
      uninflectedWord = wrd
      word = word.substring matchingPattern.length
    pushWords result, uninflectedWord, word, done
  result.join " "

###
Repeat string N times

@param {String} str Source string
@param {Number} N Times to repeat string
@return {String} result string
@api private
###
times = (str, N) ->
  s = ""
  for i in [1..N]
    s += str
  s

###
Cut first line of text. If text contains "\n" all chars after
this symbol will be removed from resulting string

@param {String} text Text string.
@param {Number} maxChars Maximum string length in chars, default - 80

@return {String} result Result string. if string length less than maxChars, it will
                        be cuncatenate with spaces
@api public
###
exports.cutFirstLine = (text, maxChars=80) ->
  ind = text.indexOf "\n"
  if 0 <= ind
    text = text.substring 0, ind
  if maxChars < text.length
    text[0..maxChars]
  else
    text + times " ", text.length - maxChars

###
Format time from datetime string

@param {String} dt Datetime string
@return {String} result Formatted time (hh/mm)
@api public
###
exports.formatTime = (dt) ->
  if "string" == typeof dt
    dt = new Date Date.parse dt
  hr = dt.getHours()
  hr = "0" + hr if 10 > hr
  m = dt.getMinutes()
  m = "0" + m if 10 > m
  "#{hr}:#{m}"


###
Format date and time from datetime string

@param {String} dt Datetime string
@return {String} result Formatted time (hh/mm)
@api public
###
exports.formatDateTime = (dt) ->
  if "string" == typeof dt
    dt = new Date Date.parse dt
  dd = dt.toString().split ' '
  m = dt.getMonth() + 1
  m = "0" + m if 10 > m
  dd[4] + " " + dd[2] + "." + m + "." + dd[3]

###
List directory, and return list of files, matching mask

@param {String} path Search path
@param {ReqExp} mask Mask for matching file
@param {Boolean} recursive If this flag is set, files will be searched recursively
@return {Array} result List of file pathes
@api public
###
exports.listDir = listDir = (path, mask=".js", recursive=true) ->
  files = []
  for f in fs.readdirSync path
    file = path + "/#{f}"
    try
      if mask == p.extname file
        files.push file
      else if recursive && fs.statSync(file).isDirectory()
        listDir(file, mask, recursive).forEach (ff) -> files.push ff
    catch err
  files

# complete = (text) ->
# ##  console.log "text = #{text}"
#   if text == 'te'
#    process.stdout.write "test"
#   else
#     text

###
Read text from standart input and call fn after user input terminator

@param {String} terminator Terminator string
@param {Function} fn Callback function, that accept one parameter - readed data
@api public
###
exports.readText = (terminator, fn) ->
  buf = ""
  stdin  = process.openStdin()
  stdout = process.stdout
  console.log  "After entering text write #{terminator.red} on new line."
  repl = readline.createInterface stdin, stdout #, complete
  repl.setPrompt '-> '
  repl.on  'close',  ->  stdin.destroy()
  repl.on  'line',   (buffer) ->
    buffer = buffer.toString()
    if terminator == buffer
      fn buf
      process.exit 0
    buf +=  buffer +  "\n"
    repl.setPrompt "   "
    repl.prompt()

  repl.prompt()

###
Read one line and make call of fn with this line

@param {String} prompt Prompt, default "->"
@param {Function} fn Callback function
###
exports.readOneLine = (prompt="->", fn) ->
  stdin  = process.openStdin()
  stdout = process.stdout
  repl = readline.createInterface stdin, stdout #, complete
  repl.setPrompt prompt
  repl.on  'close',  ->  stdin.destroy()
  repl.on  'line',   (buffer) ->
    console.log "buffer = #{buffer}"
    fn buffer.toString()
    process.exit 0
  repl.prompt()

###
Edit lines in console

@param {String} text Multiline text add to readline history and can access via keyboard
@param {String} terminator Terminator string
@param {Function} fn Callback function, that called after all text collected
@param {Boolean} lineNum Add line numbers if flag is set, default - true
###
exports.editTextLines = (text, terminator, fn, lineNum=true) ->
  buf = ""
  stdin  = process.openStdin()
  stdout = process.stdout
  console.log "Press ↑ or ↓ to access ticket content"
  console.log  "After entering text write #{terminator.red} on new line."
  repl = readline.createInterface stdin, stdout
  repl.history = []
  i = 0
  for l in text.split "\n"
    i++
    l += " [#{i}]" if lineNum
    repl.history.push l

  repl.setPrompt '-> '
  repl.on  'close',  ->  stdin.destroy()
  repl.on  'line',  (buffer) ->
    buffer = buffer.toString()
    if terminator == buffer
      fn buf
      process.exit 0
    buf +=  buffer +  "\n"
    repl.setPrompt "   "
    repl.prompt()

  repl.prompt()

