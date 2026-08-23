'use strict';

async function handler(event) {
  if (!event) {
    throw new Error('Event is required');
  }

  if (!event.eventId) {
    throw new Error('eventId is required');
  }

  if (!event.correlationId) {
    throw new Error('correlationId is required');
  }

  if (!event.receipt) {
    throw new Error('receipt is required');
  }

  const { eventId, correlationId, receipt } = event;

  const output = {
    eventId,
    correlationId,
    receipt,
    status: 'processed'
  };

  console.log(
    JSON.stringify({
      level: 'INFO',
      function: 'kk-processor',
      eventType: 'receipt.processed',
      eventId,
      correlationId,
      receiptId: receipt.receiptId,
      timestamp: new Date().toISOString()
    })
  );

  return output;
}

module.exports = {
  handler
};