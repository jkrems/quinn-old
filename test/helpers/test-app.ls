
require! http.create-server
require! request
require! create-app: '../../lib/app'
require! Url: url

last-test-port = 4000

client-with-fixed-host = (host) ->
  format-url = (url-obj) ->
    url-obj <<< { host, protocol: 'http' }
    Url.format url-obj

  make-request = (url-or-options, cb) ->
    if 'string' == typeof url-or-options
      url-or-options = format-url pathname: url-or-options
    else if url-or-options.uri?
      url-or-options.uri = format-url pathname: url-or-options.uri
    else if url-or-options.url?
      url-or-options.uri = format-url url-or-options.url
      delete url-or-options.uri

    request url-or-options, cb

  make-request

module.exports = test-app = (init) ->
  server = null
  test-port = ++last-test-port

  setup (done) ->
    app = create-app!
    init app
    server := create-server app
    server.listen test-port, -> done!

  teardown (done) ->
    server.close done

  client-with-fixed-host "127.0.0.1:#{test-port}"
