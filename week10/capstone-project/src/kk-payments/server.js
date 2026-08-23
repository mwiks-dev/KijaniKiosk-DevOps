'use strict';

const express = require('express');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const app = express();

const PORT = process.env.APP_PORT || 3001;
const RECEIPTS_BUCKET = process.env.RECEIPTS_BUCKET;
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

const s3 = new S3Client({
  region: AWS_REGION
});

app.use(express.json());

/**
 * Health check
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'kk-payments'
  });
});

/**
 * Create a payment and generate a receipt event.
 */
app.post('/payments', async (req, res) => {
  try {
    const {
      receiptId,
      amount
    } = req.body;

    if (!receiptId) {
      return res.status(400).json({
        error: 'receiptId is required'
      });
    }

    if (amount === undefined || amount === null) {
      return res.status(400).json({
        error: 'amount is required'
      });
    }

    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        error: 'amount must be a positive number'
      });
    }

    if (!RECEIPTS_BUCKET) {
      console.error(JSON.stringify({
        level: 'ERROR',
        function: 'kk-payments',
        eventType: 'receipt.creation.failed',
        message: 'RECEIPTS_BUCKET is not configured',
        timestamp: new Date().toISOString()
      }));

      return res.status(500).json({
        error: 'RECEIPTS_BUCKET is not configured'
      });
    }

    const eventId = `evt-${Date.now()}`;
    const correlationId = `corr-${Date.now()}`;
    const timestamp = new Date().toISOString();

    const receipt = {
      receiptId,
      amount,
      timestamp
    };

    const event = {
      eventId,
      correlationId,
      receipt
    };

    /*
     * Store the receipt event in S3.
     *
     * The object key uses the receipt ID so that each
     * receipt has a predictable location.
     */
    const objectKey = `receipts/${receiptId}.json`;

    const command = new PutObjectCommand({
      Bucket: RECEIPTS_BUCKET,
      Key: objectKey,
      Body: JSON.stringify(event),
      ContentType: 'application/json'
    });

    await s3.send(command);

    console.log(JSON.stringify({
      level: 'INFO',
      function: 'kk-payments',
      eventType: 'receipt.created',
      eventId,
      correlationId,
      receiptId,
      amount,
      bucket: RECEIPTS_BUCKET,
      objectKey,
      timestamp
    }));

    return res.status(201).json({
      message: 'Payment processed and receipt stored',
      event
    });

  } catch (error) {

    console.error(JSON.stringify({
      level: 'ERROR',
      function: 'kk-payments',
      eventType: 'receipt.creation.failed',
      error: error.message,
      timestamp: new Date().toISOString()
    }));

    return res.status(500).json({
      error: 'Failed to process payment'
    });
  }
});

app.use((req, res) => {
  res.status(404).json({
    error: 'not found'
  });
});

app.listen(PORT, () => {
  console.log(JSON.stringify({
    level: 'INFO',
    function: 'kk-payments',
    message: 'kk-payments service started',
    port: PORT,
    bucket: RECEIPTS_BUCKET || null,
    timestamp: new Date().toISOString()
  }));
});

module.exports = app;