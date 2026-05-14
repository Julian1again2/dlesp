const client = require('prom-client');
const express = require('express');

const app = express();
const register = new client.Registry();

const receiptSubmits = new client.Counter({ 
    name: 'dlesp_receipt_submits_total', 
    help: 'Total receipt submits' 
});

const anchorSuccess = new client.Counter({ 
    name: 'dlesp_anchor_broadcast_success_total', 
    help: 'Anchor broadcast successes' 
});

const anchorFail = new client.Counter({ 
    name: 'dlesp_anchor_broadcast_fail_total', 
    help: 'Anchor broadcast failures' 
});

register.registerMetric(receiptSubmits);
register.registerMetric(anchorSuccess);
register.registerMetric(anchorFail);

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

app.post('/emit', (req, res) => {
    console.log('📡 Event received:', req.body);
    res.json({ok: true});
});

const port = process.env.PORT || 9100;
app.listen(port, () => {
    console.log(`✅ Prometheus exporter running on port ${port}`);
});
