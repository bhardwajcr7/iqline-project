// ----- Application Insights -----
const appInsights = require("applicationinsights");
if (process.env.APPINSIGHTS_INSTRUMENTATIONKEY) {
    appInsights.setup(process.env.APPINSIGHTS_INSTRUMENTATIONKEY)
        .setAutoCollectRequests(true)
        .setAutoCollectPerformance(true)
        .setAutoCollectDependencies(true)
        .setAutoCollectExceptions(true)
        .setAutoDependencyCorrelation(true)
        .start();
}

const express = require('express');
const app = express();
const port = process.env.PORT || 3002;

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'order' }));

app.get('/orders', (req, res) => {
  res.json([
    { id: 100, item: 'Laptop', qty: 1 },
    { id: 101, item: 'Mouse', qty: 2 }
  ]);
});

module.exports = app;

if (require.main === module) {
  app.listen(port, () => console.log(`Order service running on ${port}`));
}
