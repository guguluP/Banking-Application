// Sandbox Account Aggregator stand-in.
// It does not speak to Setu, Finvu, or a real AA. It keeps a consent, returns
// one normalized batch, then deletes that batch.
const http = require("http");

const consents = new Map();

function send(res, code, body) {
  const data = JSON.stringify(body);
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(data);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  if (req.method === "POST" && url.pathname === "/v1/consent") {
    let raw = "";
    req.on("data", (chunk) => { raw += chunk; });
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      const consentId = Math.random().toString(36).slice(2, 10);
      consents.set(consentId, {
        mobile: body.mobile || "",
        events: [
          { amount: "250.00", direction: "debit", accountLast4: "0400", merchant: "Demo Store", externalRef: "UTR" + consentId, bank: "Sandbox" }
        ]
      });
      send(res, 200, { consentId });
    });
    return;
  }
  const fi = url.pathname.match(/^\/v1\/fi\/([^/]+)$/);
  if (req.method === "GET" && fi) {
    const batch = consents.get(fi[1]);
    if (!batch) {
      send(res, 404, { error: "unknown or already fetched" });
      return;
    }
    consents.delete(fi[1]);
    send(res, 200, batch.events);
    return;
  }
  send(res, 404, { error: "not found" });
});

server.listen(8787, "127.0.0.1", () => {
  console.log("AA sandbox on http://127.0.0.1:8787");
});
