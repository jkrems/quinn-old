
require! Url: url
require! querystring

require! Q: q
require! ConcatStream: 'concat-stream'

require! cookie
require! crypto.create-cipher
require! crypto.create-decipher

require '../vendor/connect/patch'

with-parsed-url = (req) ->
  [pathname, search] = req.url.split '?'
  query = querystring.parse search
  if pathname.length > 1 && pathname[pathname.length - 1] === '/'
    pathname = pathname.substr 0, pathname.length - 1

  req.protocol = req.headers['x-forwarded-proto'] ? 

  Object.defineProperties req,
    query:
      get: -> querystring.parse search

    protocol:
      get: ->
        return 'https' if @connection.encrypted
        proto = req.headers['x-forwarded-proto'] ? 'http'
        proto.split(/\s*,\s*/)[0]

    host:
      get: ->
        host = req.headers['x-forwarded-host'] ? req.headers['host']
        host ? "#{req.connection.localAddress}:#{req.connection.localPort}"

    absoluteUrl:
      get: ->
        Url.format req{protocol, pathname, host}

  req <<< { pathname }

parse-request-body = (headers, data) -->
  [mime, mimeMeta] = (headers['content-type'] || '').split ';'
  switch mime
  | 'application/x-www-form-urlencoded' => querystring.parse data.to-string!
  | _                                   => throw new Error "Unsupported mime type: #{mime}"

with-body-parser = (req) ->
  req.set-encoding 'utf8'
  Object.defineProperties req,
    body:
      get: ->
        @_bodyPromise ?= do ->
          deferred = Q.defer!
          bodyStream = new ConcatStream deferred~resolve
          bodyStream.once 'error', deferred~reject
          req.pipe bodyStream
          deferred.promise
    content:
      get: ->
        @_contentPromise ?= do ->
          req.body.then parse-request-body req.headers

with-session = (req, res) ->
  req.secret ?= 'Q9kqNvTzxGiwJ2G2xGw/DJWRCYQoOnusNAiPmaWuWLCsD6nfGOycIkn4HxJYj'
  session-secret = new Buffer req.secret, 'base64'

  tryParse = (obj) ->
    for key, raw of obj
      try
        if 0 == raw.indexOf 'j:'
          obj[key] = JSON.parse raw.substr 2
    obj

  req.cookies =
    if req.headers.cookie then tryParse cookie.parse that
    else {}

  req.session =
    if req.cookies['quinn.session']
      try
        from-cookie = JSON.parse req.cookies['quinn.session']
        decrypted   = new Buffer(from-cookie.e, 'base64').to-string 'ascii'
        # TODO: this fails an awful lot in node v0.11.5 - figure out why
        # decipher = create-decipher 'aes192', session-secret
        # decrypted   = decipher.update from-cookie.e, 'base64', 'utf8'
        # decrypted  += decipher.final 'utf8'
        JSON.parse decrypted
      catch err
        
        console.log err.stack
        {}
    else {}

  res.on 'header', ->
    if req.session?
      serialized = JSON.stringify req.session
      # TODO: this fails an awful lot in node v0.11.5 - figure out why
      # cipher = create-cipher 'aes192', session-secret
      # encrypted  = cipher.update serialized, 'utf8', 'base64'
      # encrypted += cipher.final 'base64'
      encrypted  = new Buffer(serialized, 'ascii').to-string 'base64'
      for-cookie = JSON.stringify { e: encrypted }
      res.set-header 'Set-Cookie', cookie.serialize 'quinn.session', for-cookie
    else
      res.set-header 'Set-Cookie', cookie.serialize 'quinn.session', null

  req

module.exports = patch-request = (req, res) ->
  with-parsed-url req
  with-session req, res
  with-body-parser req
