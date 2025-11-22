const request = require('supertest');
const app = require('../server');

test('health check', async () => {
  const res = await request(app).get('/health');
  expect(res.statusCode).toBe(200);
  expect(res.body.status).toBe('ok');
});
