import './register-aliases';
import http from 'http';
import app from './app';
import { config, validateEnvironment } from '@shared/config';
import { initializeSocket } from '@shared/socket';
import { ensureDatabaseIndexes } from '@shared/database/indexes';

const server = http.createServer(app);

// Initialize Socket.IO
initializeSocket(server);

// Apply database unique indexes (User.phone / User.email) before serving
// traffic so uniqueness is enforced at the storage layer, not just in code.
ensureDatabaseIndexes().catch((error) => {
  console.warn('Database index setup failed:', error);
});

server.listen(config.port, config.host, () => {
  const { warnings } = validateEnvironment();
  if (warnings.length > 0) {
    console.log('  ┌──────────────────────────────────────────────────────────┐');
    console.log('  │ DEMO / optional integrations                             │');
    for (const w of warnings) {
      console.log(`  │ - ${w.padEnd(60)}│`);
    }
    console.log('  └──────────────────────────────────────────────────────────┘');
  }
  console.log(`
  ╔══════════════════════════════════════════╗
  ║         TOSUMO API Server v1.0.0         ║
  ╠══════════════════════════════════════════╣
  ║  Environment: ${config.nodeEnv.padEnd(20)} ║
  ║  Port:        ${String(config.port).padEnd(20)} ║
  ║  Host:        ${config.host.padEnd(20)} ║
  ║  Socket.IO:   ${config.socket.path.padEnd(20)} ║
  ╚══════════════════════════════════════════╝
  `);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  server.close(() => process.exit(0));
});

export default server;
