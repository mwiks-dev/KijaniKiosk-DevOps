'use strict';

/**
 * Validate the event received by kk-notifier.
 */
function validateEvent(event) {
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

  if (!event.receipt.receiptId) {
    throw new Error('receiptId is required');
  }

  if (
    event.receipt.amount === undefined ||
    event.receipt.amount === null
  ) {
    throw new Error('amount is required');
  }

  if (typeof event.receipt.amount !== 'number') {
    throw new Error('amount must be a number');
  }

  if (!event.receipt.timestamp) {
    throw new Error('timestamp is required');
  }

  if (Number.isNaN(Date.parse(event.receipt.timestamp))) {
    throw new Error('timestamp must be a valid date');
  }
}

/**
 * Create the notification payload.
 */
function createNotification(event) {
  return {
    eventId: event.eventId,
    correlationId: event.correlationId,
    receipt: {
      receiptId: event.receipt.receiptId,
      amount: event.receipt.amount,
      timestamp: event.receipt.timestamp
    },
    status: event.status || 'processed'
  };
}

/**
 * Create and write a structured log entry.
 */
function logNotification(notification) {
  const logEntry = {
    level: 'INFO',
    function: 'kk-notifier',
    eventType: 'receipt.notified',
    eventId: notification.eventId,
    correlationId: notification.correlationId,
    receiptId: notification.receipt.receiptId,
    timestamp: new Date().toISOString()
  };

  console.log(JSON.stringify(logEntry));

  return logEntry;
}

/**
 * Lambda handler.
 */
module.exports.handler = async (event) => {
  console.log(
    'kk-notifier received event:',
    JSON.stringify(event)
  );

  // Validate the incoming processed receipt.
  validateEvent(event);

  // Create the downstream notification payload.
  const notification = createNotification(event);

  // Produce structured logging.
  logNotification(notification);

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Receipt notification processed',
      eventId: notification.eventId,
      correlationId: notification.correlationId,
      receiptId: notification.receipt.receiptId,
      notification
    })
  };
};

module.exports.validateEvent = validateEvent;
module.exports.createNotification = createNotification;
module.exports.logNotification = logNotification;