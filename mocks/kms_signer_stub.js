const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');

const app = express();
app.use(bodyParser.json());

app.post('/sign', (req, res) => {
    const payloadHex = req.body.payloadHex || req.body.inputHex;
    if (!payloadHex) {
        return res.status(400).json({ error: 'missing payloadHex' });
    }

    // Simple mock signature: sha256 of the payload
    const sig = '0x' + crypto.createHash('sha256')
        .update(Buffer.from(payloadHex, 'hex'))
        .digest('hex');

    res.json({ 
        signatureHex: sig, 
        keyId: 'did:example:ci#key-1' 
    });
});

const port = 8201;
app.listen(port, () => {
    console.log(`✅ KMS signer stub running on http://localhost:${port}`);
});
