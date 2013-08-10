
require! '../helpers/test-app'

require! expect: 'expect.js'

suite 'quinn::app', ->
  suite 'hello world app', ->
    client = test-app ->

    test 'returns 404 for root url', (done) ->
      client '/', (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 404
          expect(body).to.be 'Cannot GET /'
          expect(res.headers['content-length']).to.eql 12
          done()
        catch e then return done e

    test 'returns 404 for random url and method', (done) ->
      client { uri: '/foo-bar', method: 'PUT' }, (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 404
          expect(body).to.be 'Cannot PUT /foo-bar'
          expect(res.headers['content-length']).to.eql 19
          done()
        catch e then return done e

  suite 'simple app', ->
    client = test-app (app) ->
      app.get '/', -> 'ok'

    test 'returns 200/ok for root url', (done) ->
      client '/', (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 200
          expect(body).to.be 'ok'
          expect(res.headers['content-length']).to.eql 2
          done()
        catch e then return done e

  suite 'failing app', ->
    client = test-app (app) ->
      app.get '/', ->
        throw new Error 'Imma bug'

    test 'returns 500/error for root url', (done) ->
      client '/', (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 500
          expect(body).to.contain 'Error: Imma bug'
          expect(res.headers['content-type']).to.be 'text/plain'
          done()
        catch e then return done e
