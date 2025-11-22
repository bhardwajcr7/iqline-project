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
const axios = require('axios');
const app = express();
const { version } = require('./package.json')
const port = process.env.PORT || 3000;

// Internal service DNS inside Kubernetes
const USER_SERVICE = process.env.USER_SERVICE_URL || 'http://user-service.microservices.svc.cluster.local';
const ORDER_SERVICE = process.env.ORDER_SERVICE_URL || 'http://order-service.microservices.svc.cluster.local';

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'api-gateway', version }));

app.get('/users', async (req, res) => {
  try {
    const response = await axios.get(`${USER_SERVICE}/users`);
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: 'User service unavailable' });
  }
});

app.get('/orders', async (req, res) => {
  try {
    const response = await axios.get(`${ORDER_SERVICE}/orders`);
    res.json(response.data);
  } catch (err) {
    res.status(500).json({ error: 'Order service unavailable' });
  }
});

module.exports = app;

if (require.main === module) {
  app.listen(port, () => console.log(`API Gateway running on ${port}`));
}
