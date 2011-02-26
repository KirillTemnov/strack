require "colors"
crypto = require "crypto"
signType = "md5"
fs = require "fs"
readline = require "readline"
p = require "path"
home = process.env.HOME + "/"
exports.maxWidth = 100          # todo use this

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

class Config
  ###
  Load config. Loads config from ~/.strack.json
  If config file not exists, create it.
  Try to gather user name and email from ~/.gitconfig, if
  file not exists, get user from process.env.USER

  @return {Object} config Config object, that have "user" and "email" keys.
  @api public
  ###
  constructor: ->
    try
      @configFile = home + ".strack.json"
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
          @config.user = config.user || process.env.USER
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
    @config.log ||= "short"
    @config.secret ||= createId @config.user
    @config.defaultState ||= "todo"
    @config.showDonedTasks ||= "false"
    @config.eof ||= ".."
    @config.verbose || = "true"

  update: (params={}) ->
    for k,v of params
      @config[k] = v
    fs.writeFileSync @configFile,  JSON.stringify @config

  dump: ->
    console.log "Config parameters:"
    for k,v of @config
      console.log "#{k} = #{v}"

  get: (key) ->
    @config[key]

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

getWord = (word, re, prefixLen=1) ->
  m = word.match re
  if m
    word2 = word.substring prefixLen
    m2 = word2.match separatorCharsRe
    if m2
      return [m2[1], word2.substring m2[0].length]
  null

###
Colorize text for output to terminal.

@param {String} text Text to colorize
@param {String} pattern Search pattern, default - null
@return {String} Colored string
@api public
###
exports.colorizeText = (text, matchingPattern=null) ->
  result = []
  for word in text.split(" ")
    if 0 == word.indexOf statePrefix
      words = getWord word, stateRe, statePrefix.length
      if words
        result.push words[0].bold.underline.green + words[1]
      else
        result.push word
    else if 0 == word.indexOf tagPrefix
      words = getWord word, tagRe, tagPrefix.length
      if words
        result.push words[0].underline.grey + words[1]
      else
        result.push word
    else if 0 <= word.indexOf matchingPattern
      wrd = word.substring 0, matchingPattern.length
      wrd = wrd.bold.red
      result.push wrd +  word.substring matchingPattern.length
    else
      result.push word
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


