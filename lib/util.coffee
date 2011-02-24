crypto = require "crypto"
singType = "md5"
secret = "change me"
fs = require "fs"
path = require "path"
home = process.env.HOME + "/"

###
Create hash from string

@param {String} str Source string
@return {String} hash Hex digest hash
@api public
###
exports.createHash = (str) ->
  crypto.createHmac(singType, secret).update(str).digest("hex")


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
      throw new Exception err.toString()


