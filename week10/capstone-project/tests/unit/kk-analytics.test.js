const {
  handler,
  aggregateReceipts,
  validateReceipt,
  logSummary,
  processedEventIds
} = require('../../src/kk-analytics/handler');

describe('kk-analytics', () => {
  test('calculates receipt count', () => {
    const receipts = [
      {
        receiptId: 'RCP-001',
        amount: 1000,
        timestamp: '2026-08-23T08:00:00Z'
      },
      {
        receiptId: 'RCP-002',
        amount: 1500,
        timestamp: '2026-08-23T09:00:00Z'
      }
    ];

    const result = aggregateReceipts(receipts);

    expect(result.receiptCount).toBe(2);
  });

  test('calculates total amount', () => {
    const receipts = [
      {
        receiptId: 'RCP-001',
        amount: 1000,
        timestamp: '2026-08-23T08:00:00Z'
      },
      {
        receiptId: 'RCP-002',
        amount: 1500,
        timestamp: '2026-08-23T09:00:00Z'
      }
    ];

    const result = aggregateReceipts(receipts);

    expect(result.totalAmount).toBe(2500);
  });

  test('identifies first and last receipt timestamps', () => {
    const receipts = [
      {
        receiptId: 'RCP-001',
        amount: 1000,
        timestamp: '2026-08-23T10:00:00Z'
      },
      {
        receiptId: 'RCP-002',
        amount: 1500,
        timestamp: '2026-08-23T08:00:00Z'
      }
    ];

    const result = aggregateReceipts(receipts);

    expect(result.firstReceiptAt).toBe(
      '2026-08-23T08:00:00.000Z'
    );

    expect(result.lastReceiptAt).toBe(
      '2026-08-23T10:00:00.000Z'
    );
  });

  test('rejects a receipt without receiptId', () => {
    expect(() => {
      validateReceipt({
        amount: 1000,
        timestamp: '2026-08-23T08:00:00Z'
      });
    }).toThrow('receiptId is required');
  });

  test('rejects a receipt without amount', () => {
    expect(() => {
      validateReceipt({
        receiptId: 'RCP-001',
        timestamp: '2026-08-23T08:00:00Z'
      });
    }).toThrow('amount is required');
  });

  test('rejects a receipt without timestamp', () => {
    expect(() => {
      validateReceipt({
        receiptId: 'RCP-001',
        amount: 1000
      });
    }).toThrow('timestamp is required');
  });

  test('returns zero values for an empty receipt list', () => {
    const result = aggregateReceipts([]);

    expect(result).toEqual({
      receiptCount: 0,
      totalAmount: 0,
      firstReceiptAt: null,
      lastReceiptAt: null
    });
  });

  test('creates a structured log with correlation fields', () => {
    const log = logSummary({
      eventId: 'E001',
      correlationId: 'C001',
      receiptId: 'RCP-001',
      summary: {
        receiptCount: 1,
        totalAmount: 1500,
        firstReceiptAt: '2026-08-23T10:00:00.000Z',
        lastReceiptAt: '2026-08-23T10:00:00.000Z'
      }
    });

    expect(log.eventId).toBe('E001');
    expect(log.correlationId).toBe('C001');
    expect(log.receiptId).toBe('RCP-001');
    expect(log.function).toBe('kk-analytics');
    expect(log.timestamp).toBeDefined();
  });
});

describe('kk-analytics idempotency', () => {
  beforeEach(() => {
    processedEventIds.clear();
  });

  test('does not aggregate the same event twice', async () => {
    const event = {
      eventId: 'E001',
      correlationId: 'C001',
      receipts: [
        {
          receiptId: 'RCP-001',
          amount: 1500,
          timestamp: '2026-08-23T10:00:00Z'
        }
      ]
    };

    // First delivery should be processed
    const firstResult = await handler(event);

    // Second delivery should be identified as a duplicate
    const secondResult = await handler(event);

    expect(firstResult.receiptCount).toBe(1);
    expect(firstResult.totalAmount).toBe(1500);

    expect(secondResult.duplicate).toBe(true);
    expect(secondResult.eventId).toBe('E001');
  });
});