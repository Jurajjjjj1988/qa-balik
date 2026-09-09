// Deterministický cieľ pre sondu. Žiadna sieť, žiadne cudzie API, žiadny rate limit.
const http = require('http');

let flakyCalls = 0;

http.createServer((req, res) => {
  res.setHeader('content-type', 'application/json');

  if (req.url === '/health') {
    res.statusCode = 200;
    res.end(JSON.stringify({ status: 'UP' }));
    return;
  }

  // Striedavo 200 / 503 — DETERMINISTICKY nestabilný endpoint.
  // Slúži na dôkaz, že sonda vie odhaliť flaky bránu. Flaky brána je
  // pokazená brána: náhodná červená naučí tím ignorovať aj tú pravú.
  if (req.url === '/flaky') {
    flakyCalls += 1;
    if (flakyCalls % 2 === 1) {
      res.statusCode = 200;
      res.end(JSON.stringify({ status: 'UP', call: flakyCalls }));
    } else {
      res.statusCode = 503;
      res.end(JSON.stringify({ status: 'DOWN', call: flakyCalls }));
    }
    return;
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: 'not found' }));
}).listen(9911, () => console.log('stub-api na 9911'));
