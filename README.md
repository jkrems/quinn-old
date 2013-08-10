# quinn

```livescript
require! {
  http.create-server
  quinn.create-app
  quinn.respond
}

app = create-app!

app.get '/hello/:name', (req, {name}) ->
  "Hello #{name}"

app.get '/api', (req) ->
  respond.json message: "Hello World";

app.post '/echo', (req) ->
  respond.json req.content

server = create-server app.handle-request
server.listen process.env.PORT || 5000, ->
  console.log 'Listening.'
```

## Influences

Inspired by [Mach](https://github.com/machjs/mach) and me wanting to try out
[LiveScript](http://livescript.net/).
