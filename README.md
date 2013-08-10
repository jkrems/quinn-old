# quinn

```
var http = require('http');

var quinn = require('quinn'),
    app = quinn(),
    parse = quinn.parse,
    respond = quinn.respond;

app.get("/hello/{name}", function(req, params) {
  return "Hello " + params.name;
});

app.get("/api", function(req) {
  var message = "Hello World";
  return respond.json({ message: message });
});

app.post("/echo", function(req) {
  return respond.json(req.body);
});

http.createServer(app);
```
