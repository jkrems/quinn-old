
require! querystring

require! Q: q
require! ConcatStream: 'concat-stream'

with-parsed-url = (req) ->
  [pathname, search] = req.url.split '?'
  query = querystring.parse search
  req <<< { pathname, query }

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

module.exports = patch-request = (req) ->
  with-parsed-url req
  with-body-parser req
