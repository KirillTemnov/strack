require "colors"
crypto = require "crypto"
singType = "md5"
secret = "change me"
fs = require "fs"
home = process.env.HOME + "/"
exports.maxWidth = 100          # todo use this

# prefix for states, e.g. @todo, @done
statePrefix = "@"
# prefix for tags, e.g. +javascript, coffee-script
tagPrefix = "+"

###
Create hash from string

@param {String} str Source string
@return {String} hash Hex digest hash
@api public
###
exports.createHash = createHash = (str) ->
  crypto.createHmac(singType, secret).update(str).digest("hex")

###
Create unique ID for string

@param {String} str Source string
@return {String} hash Unique hex digest hash
@api public
###
exports.createId = createId = (str) ->
  createHash str + new Date()

###
Load config. Loads config from ~/.strack.json
If config file not exists, create it.
Try to gather user name and email from ~/.gitconfig, if
file not exists, get user from process.env.USER

@return {Object} config Config object, that have "user" and "email" keys.
@api public
###
exports.loadConfig = ->
  try
    strackjson = home + ".strack.json"
    fs.statSync strackjson
    JSON.parse fs.readFileSync strackjson
  catch err
    if 'ENOENT' == err.code
      config = {}
      try
        gitconfig = home + ".gitconfig"
        fs.statSync gitconfig
        conf = fs.readFileSync gitconfig
        for line in conf.toString().split "\n"
          line = line.trim()
          if 0 == line.indexOf "name"
            config.user = line.split("=")[1].trim()
          else if 0 == line.indexOf "email"
            config.email = line.split("=")[1].trim()
      catch err2
        config.user = config.user || process.env.USER
        config.email = config.email ||  ""
      fs.writeFileSync strackjson,  JSON.stringify config
      config
    else
      throw err

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
Make user dictionary from object

@param {Object} userdata Dictionary, containing keys "email" and "user"
@return {Object} userDict Dictionary, containing only keys "email" and "user"
@api public
###
exports.makeUserDict = (data) ->
  user: data.user, email: data.email


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
      m = word.match(/@([-\w]+)/)
      if m
        wrd = m[1].bold.underline.green
        wrd2 = word.substring m[0].length
        result.push wrd + wrd2
      else
        result.push word
    else if 0 == word.indexOf tagPrefix
      m = word.match(/\+([-\w]+)/)
      if m
        wrd = m[1].underline.grey
        wrd2 = word.substring m[0].length
        result.push wrd + wrd2
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


