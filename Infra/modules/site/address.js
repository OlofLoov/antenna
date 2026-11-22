// Redirects www to the bare domain and maps a folder address to its index.html.
function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : '';

  if (host.indexOf('www.') === 0) {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        location: { value: 'https://' + host.slice(4) + request.uri + queryString(request.querystring) }
      }
    };
  }

  var uri = request.uri;
  if (uri === '/.well-known/apple-app-site-association') {
    return request;
  }
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else if (uri.slice(uri.lastIndexOf('/') + 1).indexOf('.') === -1) {
    request.uri = uri + '/index.html';
  }
  return request;
}

function queryString(query) {
  var parts = [];
  for (var key in query) {
    var entry = query[key];
    var values = entry.multiValue ? entry.multiValue : [entry];
    for (var i = 0; i < values.length; i++) {
      parts.push(values[i].value === '' ? key : key + '=' + values[i].value);
    }
  }
  return parts.length ? '?' + parts.join('&') : '';
}
