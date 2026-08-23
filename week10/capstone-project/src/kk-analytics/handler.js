'use strict';

// Track event IDs that have already been processed.
// This provides simple idempotency for the capstone.
const processedEventIds = new Set();

/**
 * Validate the required receipt fields.
 */
function validateReceipt(receipt) {
  if (!receipt) {
    throw new Error('Receipt event is required');
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

/**
 * Aggregate receipt information.
 */
function aggregateReceipts(receipts) {
  if (!receipts || receipts.length === 0) {
    return {
      receiptCount: 0,
      totalAmount: 0,
      firstReceiptAt: null,
      lastReceiptAt: null
    };
  }

  receipts.forEach(validateReceipt);

  const totalAmount = receipts.reduce(
    (total, receipt) => total + receipt.amount,
    0
  );

  const timestamps = receipts
    .map(receipt => new Date(receipt.timestamp))
    .sort((a, b) => a - b);

  return {
    receiptCount: receipts.length,
    totalAmount,
    firstReceiptAt: timestamps[0].toISOString(),
    lastReceiptAt: timestamps[timestamps.length - 1].toISOString()
  };
}

/**
 * Create and log a structured analytics entry.
 */
function logSummary({
  eventId,
  correlationId,
  receiptId,
  summary,
  message = 'Analytics summary generated'
}) {
  const logEntry = {
    eventId,
    correlationId,
    receiptId,
    function: 'kk-analytics',
    timestamp: new Date().toISOString(),
    message,
    summary
  };

  console.log(JSON.stringify(logEntry));

  return logEntry;
}

/**
 * Lambda handler.
 */
async function handler(event) {
  const eventId = event.eventId || 'unknown';
  const correlationId = event.correlationId || 'unknown';

  // Check whether this event has already been processed.
  if (processedEventIds.has(eventId)) {
    const receiptId =
      event.receipts && event.receipts.length === 1
        ? event.receipts[0].receiptId
        : 'multiple';

    logSummary({
      eventId,
      correlationId,
      receiptId,
      summary: null,
      message: 'Duplicate event ignored'
    });
    return {
        duplicate: true,
        eventId
    }
  }

  const receipts = event.receipts || [];

  // Validate before recording the event as processed.
  receipts.forEach(validateReceipt);

  // Mark the event as processed.
  processedEventIds.add(eventId);

  const summary = aggregateReceipts(receipts);

  const receiptId =
    receipts.length === 1
      ? receipts[0].receiptId
      : 'multiple';

  logSummary({
    eventId,
    correlationId,
    receiptId,
    summary
  });

  return summary;
}

module.exports = {
  handler,
  validateReceipt,
  aggregateReceipts,
  logSummary,
  processedEventIds
};