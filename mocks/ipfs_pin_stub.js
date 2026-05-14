const express = require('express');
const app = express();
app.use(express.json());

app.post('/pin', (req, res) => {
    const cid = 'Qm' + require('crypto').randomBytes(20).toString('hex');
    console.log('📌 Mock IPFS pinned with CID:', cid);
    res.json({ cid: cid });
});

app.listen(6000, () => {
    console.log('✅ Mock IPFS pin service running on http://localhost:6000');
});
