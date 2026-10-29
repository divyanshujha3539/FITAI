import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { SignJWT, jwtVerify } from "jose";
import { database, sql } from "@/lib/db";
import type { Role } from "@/lib/roles";

export type { Role } from "@/lib/roles";
export type SessionUser = { id: string; email: string; name: string; role: Role };
const cookieName = "fitai_session";
function key() {
  const secret = process.env.SESSION_SECRET;
  if (!secret || secret.length < 32) throw new Error("SESSION_SECRET must contain at least 32 characters.");
  return new TextEncoder().encode(secret);
}
export { dashboardFor } from "@/lib/roles";

export async function startSession(user: SessionUser) {
  const token = await new SignJWT({ email: user.email, name: user.name, role: user.role })
    .setProtectedHeader({ alg: "HS256" }).setSubject(user.id).setIssuedAt().setExpirationTime("8h").sign(key());
  (await cookies()).set(cookieName, token, { httpOnly: true, secure: process.env.NODE_ENV === "production", sameSite: "lax", path: "/", maxAge: 8 * 60 * 60 });
}

export const currentUser = cache(async (): Promise<SessionUser | null> => {
  const token = (await cookies()).get(cookieName)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, key(), { algorithms: ["HS256"] });
    if (!payload.sub) return null;
    const db = await database();
    const result = await db.request().input("id", sql.NVarChar(128), payload.sub).query(`SELECT u.UserId, u.Email, u.AccountStatus, p.DisplayName, r.RoleCode FROM dbo.Users u JOIN dbo.UserRoles r ON r.UserId=u.UserId LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId WHERE u.UserId=@id`);
    const row = result.recordset[0];
    if (!row || row.AccountStatus !== "Active" || !["ADMIN", "TRAINER", "USER"].includes(row.RoleCode)) return null;
    return { id: row.UserId, email: row.Email, name: row.DisplayName || row.Email, role: row.RoleCode as Role };
  } catch { return null; }
});

export async function requireRole(...roles: Role[]) {
  const user = await currentUser();
  if (!user) return null;
  return roles.includes(user.role) ? user : null;
}

export async function logoutSession() { (await cookies()).delete(cookieName); }
