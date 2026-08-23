const {
  handler,
  validateEvent,
  createNotification,
  logNotification
} = require('../../src/kk-notifier/handler');

describe('kk-notifier', () => {
  const validEvent = {
    eventId: 'E001',
    correlationId: 'C001',
    receipt: {
      receiptId: 'RCP-001',
      amount: 1500,
      timestamp: '2026-08-23T10:00:00Z'
    },
    status: 'processed'
  };

  describe('validateEvent', () => {
    test('accepts a valid processed receipt event', () => {
      expect(() => {
        validateEvent(validEvent);
      }).not.toThrow();
    });

    test('rejects a missing event', () => {
      expect(() => {
        validateEvent(null);
      }).toThrow('Event is required');
    });

    test('rejects an event without eventId', () => {
      const event = {
        ...validEvent,
        eventId: undefined
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('eventId is required');
    });

    test('rejects an event without correlationId', () => {
      const event = {
        ...validEvent,
        correlationId: undefined
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('correlationId is required');
    });

    test('rejects an event without receipt', () => {
      const event = {
        ...validEvent,
        receipt: undefined
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('receipt is required');
    });

    test('rejects a receipt without receiptId', () => {
      const event = {
        ...validEvent,
        receipt: {
          ...validEvent.receipt,
          receiptId: undefined
        }
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('receiptId is required');
    });

    test('rejects a receipt without amount', () => {
      const event = {
        ...validEvent,
        receipt: {
          ...validEvent.receipt,
          amount: undefined
        }
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('amount is required');
    });

    test('rejects a receipt with a non-numeric amount', () => {
      const event = {
        ...validEvent,
        receipt: {
          ...validEvent.receipt,
          amount: '1500'
        }
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('amount must be a number');
    });

    test('rejects a receipt without timestamp', () => {
      const event = {
        ...validEvent,
        receipt: {
          ...validEvent.receipt,
          timestamp: undefined
        }
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('timestamp is required');
    });

    test('rejects an invalid timestamp', () => {
      const event = {
        ...validEvent,
        receipt: {
          ...validEvent.receipt,
          timestamp: 'not-a-date'
        }
      };

      expect(() => {
        validateEvent(event);
      }).toThrow('timestamp must be a valid date');
    });
  });

  describe('createNotification', () => {
    test('creates the expected notification payload', () => {
      const result = createNotification(validEvent);

      expect(result).toEqual({
        eventId: 'E001',
        correlationId: 'C001',
        receipt: {
          receiptId: 'RCP-001',
          amount: 1500,
          timestamp: '2026-08-23T10:00:00Z'
        },
        status: 'processed'
      });
    });

    test('defaults status to processed when status is missing', () => {
      const event = {
        ...validEvent,
        status: undefined
      };

      const result = createNotification(event);

      expect(result.status).toBe('processed');
    });
  });

  describe('logNotification', () => {
    test('creates structured notification log', () => {
      const log = logNotification(
        createNotification(validEvent)
      );

      expect(log.level).toBe('INFO');
      expect(log.function).toBe('kk-notifier');
      expect(log.eventType).toBe('receipt.notified');
      expect(log.eventId).toBe('E001');
      expect(log.correlationId).toBe('C001');
      expect(log.receiptId).toBe('RCP-001');
      expect(log.timestamp).toBeDefined();
    });
  });

  describe('handler', () => {
    test('processes a valid receipt notification', async () => {
      const result = await handler(validEvent);

      expect(result.statusCode).toBe(200);

      const body = JSON.parse(result.body);

      expect(body.message).toBe(
        'Receipt notification processed'
      );

      expect(body.eventId).toBe('E001');
      expect(body.correlationId).toBe('C001');
      expect(body.receiptId).toBe('RCP-001');

      expect(body.notification).toEqual({
        eventId: 'E001',
        correlationId: 'C001',
        receipt: {
          receiptId: 'RCP-001',
          amount: 1500,
          timestamp: '2026-08-23T10:00:00Z'
        },
        status: 'processed'
      });
    });

    test('rejects an invalid event', async () => {
      await expect(
        handler({
          eventId: 'E001',
          correlationId: 'C001'
        })
      ).rejects.toThrow('receipt is required');
    });
  });
});