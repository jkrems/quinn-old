# quinn

```
var http = require('http');

var quinn = require('quinn'),
    app = quinn.createApp(),
    respond = quinn.respond;

app.get("/hello/:name", function(req, params) {
  return "Hello " + params.name;
});

app.get("/api", function(req) {
  var message = "Hello World";
  return respond.json({ message: message });
});

app.post("/echo", function(req) {
  return respond.json(req.content);
});

http.createServer(app.handleRequest)
.listen(process.env.PORT || 5000);
```

## Influences

Inspired by [Mach](https://github.com/machjs/mach) and me wanting to try out
[LiveScript](http://livescript.net/).
