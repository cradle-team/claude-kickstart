#!/usr/bin/env node

const { main } = require('../lib/installer');
main().catch(err => {
  console.error('\x1b[31m%s\x1b[0m', `Error: ${err.message}`);
  process.exit(1);
});
