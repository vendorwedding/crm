// Adapter Netlify -> logika bersama di lib/api.js
const { handle } = require('../../lib/api.js');
exports.handler = async (e) => {
  const r = await handle('calendar', { method: e.httpMethod, headers: k => e.headers[String(k).toLowerCase()], body: e.body || '', query: e.queryStringParameters || {} }, process.env);
  return { statusCode: r.status, headers: r.headers, body: r.body };
};
