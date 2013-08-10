
require! 'json-stringify-safe'

module.exports = respond = (result, res) -->
  {body, status, headers} = result
  res.writeHead status, headers
  res.end body

respond <<< text: (body, status = 200, _headers = {}) ->
  headers = {
    'Content-Type': 'text/plain'
    'Content-Length': Buffer.byteLength body
  } <<< _headers
  respond { body, status, headers }

respond <<< json: (obj, status = 200, _headers = {}) ->
  body = JSON.stringify obj
  headers = {
    'Content-Type': 'application/json'
    'Content-Length': Buffer.byteLength body
  } <<< _headers
  respond { body, status, headers }

respond <<< jsonSafe: (obj, status = 200, _headers = {}) ->
  body = json-stringify-safe obj
  headers = {
    'Content-Type': 'application/json'
    'Content-Length': Buffer.byteLength body
  } <<< _headers
  respond { body, status, headers }
