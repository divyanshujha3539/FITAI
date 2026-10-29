import "server-only";
import sql from "mssql";

let pool: Promise<sql.ConnectionPool> | undefined;
export function database() {
  const { AZURE_SQL_SERVER, AZURE_SQL_DATABASE, AZURE_SQL_USER, AZURE_SQL_PASSWORD } = process.env;
  if (!AZURE_SQL_SERVER || !AZURE_SQL_DATABASE || !AZURE_SQL_USER || !AZURE_SQL_PASSWORD) {
    throw new Error("Database is not configured. Set AZURE_SQL_SERVER, AZURE_SQL_DATABASE, AZURE_SQL_USER, and AZURE_SQL_PASSWORD.");
  }
  pool ??= new sql.ConnectionPool({ server: AZURE_SQL_SERVER, database: AZURE_SQL_DATABASE, user: AZURE_SQL_USER, password: AZURE_SQL_PASSWORD, options: { encrypt: true, trustServerCertificate: false }, pool: { max: 10, min: 0, idleTimeoutMillis: 30000 } }).connect();
  return pool;
}

export { sql };
