'use strict';

// 1. Validation Function
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

  if (!receipt.timestamp) {
    throw new Error('timestamp is required');
  }

  if (typeof receipt.amount !== 'number') {
    throw new Error('amount must be a number');
  }

  if (Number.isNaN(Date.parse(receipt.timestamp))) {
    throw new Error('timestamp must be a valid date');
  }
}

// 2. Aggregation function
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

// 3. Lambda handler
module.exports.handler = async (event) => {
  console.log(
    'kk-analytics received event:',
    JSON.stringify(event)
  );

  const receipts = event.receipts || [];

  const summary = aggregateReceipts(receipts);

  console.log(
    'kk-analytics summary:',
    JSON.stringify(summary)
  );

  return summary;
};
// Export helpers so Jest can test them
module.exports.validateReceipt = validateReceipt;
module.exports.aggregateReceipts = aggregateReceipts;