crypto = require "crypto"
singType = "md5"
secret = "change me"

exports.createHash = (str) ->
  crypto.createHmac(singType, secret).update(str).digest("hex")



