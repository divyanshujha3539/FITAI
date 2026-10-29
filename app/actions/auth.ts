"use server";
import { redirect } from "next/navigation";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { database, sql } from "@/lib/db";
import { dashboardFor, logoutSession, startSession, type Role } from "@/lib/auth";
import { isPublicRegistrationRole } from "@/lib/roles";

const emailRule = z.string().trim().email().max(320);
const passwordRule = z.string().min(10).max(128).regex(/[a-z]/).regex(/[A-Z]/).regex(/[0-9]/);
const formString = (form: FormData, key: string) => String(form.get(key) ?? "").trim();
export type AuthState = { error?: string } | undefined;

export async function signIn(_state: AuthState, form: FormData): Promise<AuthState> {
  const email = formString(form, "email").toLowerCase();
  const password = String(form.get("password") ?? "");
  const selectedRole = formString(form, "role") as Role;
  if (!emailRule.safeParse(email).success || !password || !["ADMIN", "TRAINER", "USER"].includes(selectedRole)) return { error: "Enter your email, password, and account type." };
  try {
    const db = await database();
    if (selectedRole === "ADMIN") await provisionAdmin(db);
    const result = await db.request().input("email", sql.NVarChar(320), email).query(`SELECT u.UserId,u.Email,u.AccountStatus,p.DisplayName,i.PasswordHash,r.RoleCode FROM dbo.Users u JOIN dbo.UserRoles r ON r.UserId=u.UserId JOIN dbo.UserIdentities i ON i.UserId=u.UserId AND i.Provider='password' LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId WHERE u.Email=@email`);
    const row = result.recordset[0];
    if (!row || row.AccountStatus !== "Active" || row.RoleCode !== selectedRole || !row.PasswordHash || !(await bcrypt.compare(password, row.PasswordHash))) return { error: "Those credentials do not match an active account with that role." };
    await startSession({ id: row.UserId, email: row.Email, name: row.DisplayName || row.Email, role: row.RoleCode });
  } catch { return { error: "Sign in is temporarily unavailable. Check the database and session configuration." }; }
  redirect(dashboardFor(selectedRole));
}

async function provisionAdmin(db: sql.ConnectionPool) {
  const email = process.env.INITIAL_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.INITIAL_ADMIN_PASSWORD;
  if (!email || !password) throw new Error("Set INITIAL_ADMIN_EMAIL and INITIAL_ADMIN_PASSWORD to provision the initial administrator.");
  if (!emailRule.safeParse(email).success || !passwordRule.safeParse(password).success) throw new Error("Initial administrator configuration is invalid.");
  const exists = await db.request().input("email", sql.NVarChar(320), email).query("SELECT UserId FROM dbo.Users WHERE Email=@email");
  if (exists.recordset.length) return;
  const id = crypto.randomUUID();
  const hash = await bcrypt.hash(password, 12);
  const tx = new sql.Transaction(db);
  await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
  try {
    const request = new sql.Request(tx).input("id", sql.NVarChar(128), id).input("email", sql.NVarChar(320), email).input("hash", sql.NVarChar(255), hash);
    await request.query(`INSERT dbo.Users(UserId,Email) VALUES(@id,@email); INSERT dbo.UserProfiles(UserId,DisplayName) VALUES(@id,N'Administrator'); INSERT dbo.UserRoles(UserId,RoleCode) VALUES(@id,'ADMIN'); INSERT dbo.UserIdentities(UserId,Provider,ProviderSubject,PasswordHash) VALUES(@id,'password',@email,@hash);`);
    await tx.commit();
  } catch (error) { await tx.rollback(); if ((error as { number?: number }).number !== 2627) throw error; }
}

export async function register(_state: AuthState, form: FormData): Promise<AuthState> {
  const role = formString(form, "role");
  const name = formString(form, "name");
  const email = formString(form, "email").toLowerCase();
  const password = String(form.get("password") ?? "");
  const confirm = String(form.get("confirmPassword") ?? "");
  const phone = formString(form, "phone");
  const specialization = formString(form, "specialization");
  const experience = formString(form, "experience");
  if (!isPublicRegistrationRole(role) || name.length < 2 || name.length > 100 || !emailRule.safeParse(email).success || !passwordRule.safeParse(password).success || password !== confirm || (phone && !/^[+()\d\s.-]{7,30}$/.test(phone)) || (role === "TRAINER" && (!specialization || specialization.length > 300 || (experience && (!/^\d{1,2}$/.test(experience) || Number(experience) > 60))))) return { error: "Check the fields. Passwords need 10+ characters, upper and lowercase letters, and a number." };
  try {
    const db = await database();
    const id = crypto.randomUUID();
    const hash = await bcrypt.hash(password, 12);
    const tx = new sql.Transaction(db);
    await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    const request = new sql.Request(tx).input("id", sql.NVarChar(128), id).input("email", sql.NVarChar(320), email).input("name", sql.NVarChar(100), name).input("hash", sql.NVarChar(255), hash).input("phone", sql.NVarChar(30), phone || null).input("specialization", sql.NVarChar(300), specialization).input("experience", sql.TinyInt, experience ? Number(experience) : null);
    try {
      await request.query(`INSERT dbo.Users(UserId,Email) VALUES(@id,@email); INSERT dbo.UserProfiles(UserId,DisplayName) VALUES(@id,@name); INSERT dbo.UserRoles(UserId,RoleCode) VALUES(@id,'${role}'); INSERT dbo.UserIdentities(UserId,Provider,ProviderSubject,PasswordHash) VALUES(@id,'password',@email,@hash); ${role === "TRAINER" ? "INSERT dbo.TrainerProfiles(UserId,Phone,Specialization,ExperienceYears) VALUES(@id,@phone,@specialization,@experience);" : ""}`);
      await tx.commit();
    } catch (error) { await tx.rollback(); throw error; }
  } catch (error) {
    if ((error as { number?: number }).number === 2627 || (error as { number?: number }).number === 2601) return { error: "An account with that email already exists." };
    return { error: "Registration is temporarily unavailable. Check the database configuration and migrations." };
  }
  redirect("/login?registered=1");
}

export async function signOut() { await logoutSession(); redirect("/login"); }
