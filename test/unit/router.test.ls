
require! '../../lib/router'
require! '../../lib/discover-controllers'
require! expect: 'expect.js'

some-handler = ->

some-controller =
  foo: -> 'ok'
  index: -> 'idx'

controller = discover-controllers []
controller.register-controller 'some', some-controller

suite 'quinn::router', ->
  match-route = null

  setup ->
    {}
    match-route := router controller

  test 'returns null for an empty router', ->
    match-route = router!
    route = match-route method: 'GET', pathname: '/'
    expect(route).to.be null

  test 'creates splat-matches', ->
    match-route = router!
    match-route.push-route '/house.*', some-handler, {}, [ 'GET' ]

    route = match-route method: 'GET', pathname: '/house.json'
    expect(route.handler).to.be some-handler
    expect(route.params).to.eql [ '/house.json', 'json' ]
    expect(route.params.splat).to.eql 'json'

  test 'matches a simple GET-request to "/" correctly', ->
    match-route = router!
    match-route.push-route '/', some-handler, {}, [ 'GET' ]

    route = match-route method: 'GET', pathname: '/'
    expect(route.handler).to.be some-handler
    expect(route.params).to.eql [ '/' ]

    route = match-route method: 'PUT', pathname: '/'
    expect(route).to.be null

  test 'matches a POST-request to "/" correctly', ->
    match-route = router!
    match-route.push-route '/', some-handler, {}, [ 'POST' ]

    route = match-route method: 'POST', pathname: '/'
    expect(route.handler).to.be some-handler
    expect(route.params).to.eql [ '/' ]

    route = match-route method: 'GET', pathname: '/'
    expect(route).to.be null

  test 'matches a PUT-request with segment /{name}/bar to "/jim/bar" correctly', ->
    match-route = router!
    match-route.push-route '/{name}/bar', some-handler

    route = match-route method: 'PUT', pathname: '/jim/bar'
    expect(route.handler).to.be some-handler
    expect(route.params).to.eql [ '/jim/bar', 'jim' ]
    expect(route.params.name).to.be 'jim'

  suite 'reverse routing', ->
    reverse-route = null

    setup ->
      match-route = router controller
      match-route.push-route '/zapp', 'some.foo'
      match-route.push-route '/{name}/bar', 'some.foo'
      match-route.push-route '/rainbow.*', 'some.foo'
      {reverse-route} := match-route

    test 'can route with placeholder', ->
      rev = reverse-route! 'some.foo', name: 'zzz'
      expect(rev).to.be '/zzz/bar'

    test 'accepts route without placeholder', ->
      rev = reverse-route! 'some.foo'
      expect(rev).to.be '/zapp'

    test 'add additional params as query params', ->
      rev = reverse-route! 'some.foo', name: '123', q: 'grep'
      expect(rev).to.be '/123/bar?q=grep'

      rev = reverse-route! 'some.foo', q: 'grep'
      expect(rev).to.be '/zapp?q=grep'

    test 'supports * -> splat', ->
      rev = reverse-route! 'some.foo', splat: 'html'
      expect(rev).to.be '/rainbow.html'

      rev = reverse-route! 'some.foo', 'splat', 'html'
      expect(rev).to.be '/rainbow.html'
