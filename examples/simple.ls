require! {
  http.create-server
  '../lib/quinn'
  '../lib/respond'
}

app = quinn.create-app!

app.get '/hello/:name', (req, {name}) ->
  "Hello #{name}"

app.get '/api', (req) ->
  respond.json message: "Hello World";

app.post '/echo', (req) ->
  respond.json req.content

server = create-server app.handle-request
server.listen process.env.PORT || 5000, ->
  console.log 'Listening.'
