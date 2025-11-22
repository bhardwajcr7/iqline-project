const express = require('express');
const app = express();
const port = process.env.PORT || 3001;

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'user' }));

app.get('/users', (req, res) => {
  res.json([
    { id: 1, name: 'Sanyog' },
    { id: 2, name: 'John' }
  ]);
});

module.exports = app;

if (require.main === module) {
  app.listen(port, () => console.log(`User service running on ${port}`));
}
