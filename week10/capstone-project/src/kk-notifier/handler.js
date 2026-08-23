'use strict';

module.exports.handler = async (event) => {
  console.log('kk-notifier received event:', JSON.stringify(event));

  // Existing notification logic
  // ...

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Receipt notification processed'
    })
  };
};