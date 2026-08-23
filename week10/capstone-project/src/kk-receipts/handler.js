'use strict';

function validateReceipt(receipt) {
  if (!receipt) {
    throw new Error('Receipt is required');
  }

  if (!receipt.receiptId) {
    throw new Error('receiptId is required');
  }

  if (receipt.amount === undefined || receipt.amount === null) {
    throw new Error('amount is required');
  }

  if (typeof receipt.amount !== 'number') {
    throw new Error('amount must be a number');
  }

  if (!receipt.timestamp) {
    throw new Error('timestamp is required');
  }

  if (Number.isNaN(Date.parse(receipt.timestamp))) {
    throw new Error('timestamp must be a valid date');
  }
}

async function handler(event) {
  const eventId = event.eventId || `evt-${Date.now()}`;
  const correlationId =
    event.correlationId || `corr-${Date.now()}`;

  const receipt = event.receipt;

  validateReceipt(receipt);

  const output = {
    eventId,
    correlationId,
    receipt
  };

  console.log(
    JSON.stringify({
      level: 'INFO',
      function: 'kk-receipts',
      eventType: 'receipt.received',
      eventId,
      correlationId,
      receiptId: receipt.receiptId,
      timestamp: new Date().toISOString()
    })
  );

  return output;
}

module.exports = {
  handler,
  validateReceipt
};