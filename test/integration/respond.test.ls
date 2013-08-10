
require! expect: 'expect.js'

require! '../../lib/respond'

require! '../helpers/test-app'

suite 'quinn::respond', ->
  suite 'json', ->
    client = test-app (app) ->
      app.get '/obj', -> respond.json foo: 'bar'
      app.get '/void', -> respond.json!
      app.post '/echo', (req)-> respond.json req.content

    test 'JSON object', (done) ->
      client '/obj', (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 200
          expect(body).to.be '{"foo":"bar"}'
          expect(res.headers['content-type']).to.be 'application/json; charset=utf-8'
          expect(res.headers['content-length']).to.eql 13
          done()
        catch e then return done e

    test 'JSON undefined -> null', (done) ->
      client '/void', (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 200
          expect(body).to.be 'null'
          expect(res.headers['content-type']).to.be 'application/json; charset=utf-8'
          expect(res.headers['content-length']).to.eql 4
          done()
        catch e then return done e

    test 'promised body -> JSON', (done) ->
      client { uri: '/echo', method: 'POST', form: { a: 42 } }, (err, res, body) ->
        return done(err) if err?
        try
          expect(res.status-code).to.be 200
          expect(body).to.be '{"a":"42"}'
          expect(res.headers['content-type']).to.be 'application/json; charset=utf-8'
          expect(res.headers['content-length']).to.eql 10
          done()
        catch e then return done e
