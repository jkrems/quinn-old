
require! '../../lib/router'
require! expect: 'expect.js'

suite 'quinn::router', ->
  test 'returns null for an empty router', ->
    match-route = router!
    route = match-route method: 'GET', pathname: '/'
    expect(route).to.be null

  test 'matches a simple GET-request to "/" correctly', ->
    match-route = router!
    match-route.push-route '/', 'ok', [ 'GET' ]

    route = match-route method: 'GET', pathname: '/'
    expect(route.handler).to.be 'ok'
    expect(route.params).to.eql [ '/' ]

  test 'matches a POST-request to "/" correctly', ->
    match-route = router!
    match-route.push-route '/', 'ok', [ 'POST' ]

    route = match-route method: 'POST', pathname: '/'
    expect(route.handler).to.be 'ok'
    expect(route.params).to.eql [ '/' ]

  test 'matches a PUT-request with segment /:name/bar to "/jim/bar" correctly', ->
    match-route = router!
    match-route.push-route '/:name/bar', 'ok'

    route = match-route method: 'PUT', pathname: '/jim/bar'
    expect(route.handler).to.be 'ok'
    expect(route.params).to.eql [ '/jim/bar', 'jim' ]
    expect(route.params.name).to.be 'jim'
