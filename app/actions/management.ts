"use server";
import { redirect } from "next/navigation";
import { currentUser } from "@/lib/auth";
import { database, sql } from "@/lib/db";

export async function requestTrainer(form: FormData) {
  const user = await currentUser(); if (!user || user.role !== "USER") redirect("/login");
  const notes = String(form.get("notes") ?? "").trim().slice(0, 500);
  const db = await database();
  const active = await db.request().input("id", sql.NVarChar(128), user.id).query("SELECT TOP(1) 1 AS HasAssignment FROM dbo.TrainerAssignments WHERE UserId=@id AND EndedAtUtc IS NULL");
  if (active.recordset.length) redirect("/user");
  try {
    await db.request().input("id", sql.NVarChar(128), user.id).input("notes", sql.NVarChar(500), notes || null).query("INSERT dbo.TrainerRequests(UserId,Notes) SELECT @id,@notes WHERE NOT EXISTS (SELECT 1 FROM dbo.TrainerRequests WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@id AND RequestStatus='Pending')");
  } catch (error) { if ((error as { number?: number }).number !== 2601 && (error as { number?: number }).number !== 2627) throw error; }
  redirect("/user");
}

export async function updateOwnProfile(form: FormData) {
  const user = await currentUser(); if (!user) redirect("/login");
  const name = String(form.get("name") ?? "").trim();
  if (name.length < 2 || name.length > 100) redirect(user.role === "TRAINER" ? "/trainer?profile=invalid" : "/user?profile=invalid");
  const db = await database();
  await db.request().input("id", sql.NVarChar(128), user.id).input("name", sql.NVarChar(100), name).query("UPDATE dbo.UserProfiles SET DisplayName=@name,UpdatedAtUtc=SYSUTCDATETIME() WHERE UserId=@id");
  redirect(user.role === "TRAINER" ? "/trainer?profile=saved" : "/user?profile=saved");
}

export async function updateTrainerProfile(form: FormData) {
  const user = await currentUser(); if (!user || user.role !== "TRAINER") redirect("/login");
  const specialization = String(form.get("specialization") ?? "").trim();
  const phone = String(form.get("phone") ?? "").trim();
  const experience = String(form.get("experience") ?? "").trim();
  if (!specialization || specialization.length > 300 || (phone && !/^[+()\d\s.-]{7,30}$/.test(phone)) || (experience && (!/^\d{1,2}$/.test(experience) || Number(experience) > 60))) redirect("/trainer?profile=invalid");
  const db = await database();
  await db.request().input("id", sql.NVarChar(128), user.id).input("specialization", sql.NVarChar(300), specialization).input("phone", sql.NVarChar(30), phone || null).input("experience", sql.TinyInt, experience ? Number(experience) : null).query("UPDATE dbo.TrainerProfiles SET Specialization=@specialization,Phone=@phone,ExperienceYears=@experience WHERE UserId=@id");
  redirect("/trainer?profile=saved");
}

export async function setTrainerApproval(form: FormData) {
  const admin = await currentUser(); if (!admin || admin.role !== "ADMIN") redirect("/login");
  const trainerId = String(form.get("trainerId") ?? ""); const status = String(form.get("status") ?? "");
  if (!trainerId || !["Approved", "Rejected"].includes(status)) redirect("/admin");
  const db = await database(); const tx = new sql.Transaction(db); await tx.begin();
  try {
    await new sql.Request(tx).input("trainer", sql.NVarChar(128), trainerId).input("status", sql.VarChar(10), status).input("admin", sql.NVarChar(128), admin.id).query(`UPDATE tp SET ApprovalStatus=@status FROM dbo.TrainerProfiles tp JOIN dbo.UserRoles r ON r.UserId=tp.UserId AND r.RoleCode='TRAINER' WHERE tp.UserId=@trainer; IF @status='Rejected' UPDATE dbo.TrainerAssignments SET EndedAtUtc=SYSUTCDATETIME() WHERE TrainerId=@trainer AND EndedAtUtc IS NULL; INSERT dbo.AdminAuditEvents(AdminUserId,EventType,SubjectUserId,Details) VALUES(@admin,'Trainer'+@status,@trainer,'Trainer approval changed by admin');`);
    await tx.commit();
  } catch (error) { await tx.rollback(); throw error; }
  redirect("/admin");
}

export async function rejectTrainerRequest(form: FormData) {
  const admin = await currentUser(); if (!admin || admin.role !== "ADMIN") redirect("/login");
  const requestId = Number(form.get("requestId"));
  if (!Number.isSafeInteger(requestId) || requestId <= 0) redirect("/admin");
  const db = await database();
  await db.request().input("requestId", sql.BigInt, requestId).input("admin", sql.NVarChar(128), admin.id).query(`SET XACT_ABORT ON; BEGIN TRANSACTION; DECLARE @UserId nvarchar(128); SELECT @UserId=UserId FROM dbo.TrainerRequests WITH(UPDLOCK,HOLDLOCK) WHERE TrainerRequestId=@requestId AND RequestStatus='Pending'; IF @UserId IS NOT NULL BEGIN UPDATE dbo.TrainerRequests SET RequestStatus='Rejected',UpdatedAtUtc=SYSUTCDATETIME() WHERE TrainerRequestId=@requestId; INSERT dbo.AdminAuditEvents(AdminUserId,EventType,SubjectUserId,Details) VALUES(@admin,'TrainerRequestRejected',@UserId,'Member trainer request rejected by admin'); END; COMMIT TRANSACTION;`);
  redirect("/admin");
}

export async function assignTrainer(form: FormData) {
  const admin = await currentUser(); if (!admin || admin.role !== "ADMIN") redirect("/login");
  const userId = String(form.get("userId") ?? ""); const trainerId = String(form.get("trainerId") ?? "");
  if (!userId || !trainerId || userId === trainerId) redirect("/admin");
  const db = await database(); const tx = new sql.Transaction(db); await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
  try {
    const request = new sql.Request(tx).input("user", sql.NVarChar(128), userId).input("trainer", sql.NVarChar(128), trainerId).input("admin", sql.NVarChar(128), admin.id);
    const valid = await request.query(`SELECT u.UserId FROM dbo.Users u WITH(UPDLOCK,HOLDLOCK) JOIN dbo.UserRoles ur ON ur.UserId=u.UserId AND ur.RoleCode='USER' JOIN dbo.TrainerProfiles tp ON tp.UserId=@trainer AND tp.ApprovalStatus='Approved' JOIN dbo.UserRoles tr ON tr.UserId=tp.UserId AND tr.RoleCode='TRAINER' WHERE u.UserId=@user AND u.AccountStatus='Active'`);
    if (!valid.recordset.length) throw new Error("Customer or approved trainer not found");
    await request.query(`DECLARE @RequestId bigint=(SELECT TOP(1) TrainerRequestId FROM dbo.TrainerRequests WHERE UserId=@user AND RequestStatus='Pending' ORDER BY CreatedAtUtc DESC); UPDATE dbo.TrainerAssignments SET EndedAtUtc=SYSUTCDATETIME() WHERE UserId=@user AND EndedAtUtc IS NULL; INSERT dbo.TrainerAssignments(UserId,TrainerId,TrainerRequestId,AssignedByUserId) VALUES(@user,@trainer,@RequestId,@admin); UPDATE dbo.TrainerRequests SET RequestStatus='Assigned',UpdatedAtUtc=SYSUTCDATETIME() WHERE TrainerRequestId=@RequestId; INSERT dbo.AdminAuditEvents(AdminUserId,EventType,SubjectUserId,Details) VALUES(@admin,'TrainerAssigned',@user,CONCAT('Trainer: ',@trainer));`);
    await tx.commit();
  } catch (error) { await tx.rollback(); console.error("Trainer assignment rejected", error instanceof Error ? error.message : "unknown"); }
  redirect("/admin");
}
