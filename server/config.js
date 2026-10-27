import 'dotenv/config';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  plumberUrl: process.env.PLUMBER_URL || 'http://localhost:8765',
  dbFile: process.env.DB_FILE || './server/db/analisis.db',
};
