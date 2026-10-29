import { redirect } from "next/navigation";
import { currentUser, dashboardFor } from "@/lib/auth";
import { database, sql } from "@/lib/db";
import { signOut } from "@/app/actions/auth";
import { assignTrainer, rejectTrainerRequest, setTrainerApproval } from "@/app/actions/management";
import { ConfirmSubmit } from "@/components/confirm-submit";

export const instant = false;
type Customer = { UserId: string; Customer: string; Email: string; Trainer: string | null; TrainerEmail: string | null; AssignmentStatus: string; AssignedDate: Date | null };
type Trainer = { UserId: string; Name: string; Email: string; Specialization: string; ApprovalStatus: string };
type RequestRow = { TrainerRequestId: number; DisplayName: string | null; Email: string; Notes: string | null; RequestStatus: string; CreatedAtUtc: Date };
type AuditRow = { EventType: string; Details: string | null; CreatedAtUtc: Date; AdminName: string | null };

export default async function AdminHome({ searchParams }: { searchParams: Promise<{ q?: string; assignment?: string; trainer?: string; request?: string }> }) {
  const admin = await currentUser();
  if (!admin) redirect("/login");
  if (admin.role !== "ADMIN") redirect(dashboardFor(admin.role));
  const filters = await searchParams;
  const query = (filters.q ?? "").trim().slice(0, 100);
  const assignment = ["Assigned", "Unassigned"].includes(filters.assignment ?? "") ? filters.assignment : "";
  const trainerId = (filters.trainer ?? "").slice(0, 128);
  const requestStatus = ["Pending", "Assigned", "Rejected", "Approved"].includes(filters.request ?? "") ? filters.request : "";
  const conditions = `${query ? " AND (p.DisplayName LIKE @q OR u.Email LIKE @q)" : ""}${assignment === "Assigned" ? " AND a.TrainerId IS NOT NULL" : assignment === "Unassigned" ? " AND a.TrainerId IS NULL" : ""}${trainerId ? " AND a.TrainerId=@trainer" : ""}${requestStatus ? " AND EXISTS(SELECT 1 FROM dbo.TrainerRequests fr WHERE fr.UserId=u.UserId AND fr.RequestStatus=@requestStatus)" : ""}`;
  const db = await database();
  const customerQuery = db.request().input("q", sql.NVarChar(210), `%${query}%`).input("trainer", sql.NVarChar(128), trainerId || null).input("requestStatus", sql.VarChar(10), requestStatus || null);
  const [customers, trainers, requests, audit] = await Promise.all([
    customerQuery.query(`SELECT u.UserId,p.DisplayName AS Customer,u.Email,tp.DisplayName AS Trainer,tu.Email AS TrainerEmail,CASE WHEN a.TrainerAssignmentId IS NULL THEN 'Unassigned' ELSE 'Assigned' END AS AssignmentStatus,a.AssignedAtUtc AS AssignedDate FROM dbo.Users u JOIN dbo.UserRoles r ON r.UserId=u.UserId AND r.RoleCode='USER' LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId LEFT JOIN dbo.TrainerAssignments a ON a.UserId=u.UserId AND a.EndedAtUtc IS NULL LEFT JOIN dbo.UserProfiles tp ON tp.UserId=a.TrainerId LEFT JOIN dbo.Users tu ON tu.UserId=a.TrainerId WHERE 1=1${conditions} ORDER BY p.DisplayName,u.Email`),
    db.request().query("SELECT u.UserId,p.DisplayName AS Name,u.Email,tp.Specialization,tp.ApprovalStatus FROM dbo.TrainerProfiles tp JOIN dbo.Users u ON u.UserId=tp.UserId JOIN dbo.UserRoles r ON r.UserId=u.UserId AND r.RoleCode='TRAINER' LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId ORDER BY tp.ApprovalStatus,p.DisplayName"),
    db.request().query("SELECT r.TrainerRequestId,p.DisplayName,u.Email,r.Notes,r.RequestStatus,r.CreatedAtUtc FROM dbo.TrainerRequests r JOIN dbo.Users u ON u.UserId=r.UserId LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId ORDER BY CASE r.RequestStatus WHEN 'Pending' THEN 0 ELSE 1 END,r.CreatedAtUtc DESC"),
    db.request().query("SELECT TOP(20) e.EventType,e.Details,e.CreatedAtUtc,p.DisplayName AS AdminName FROM dbo.AdminAuditEvents e LEFT JOIN dbo.UserProfiles p ON p.UserId=e.AdminUserId ORDER BY e.CreatedAtUtc DESC"),
  ]);
  const rows = customers.recordset as Customer[];
  const coaches = trainers.recordset as Trainer[];
  const requestRows = requests.recordset as RequestRow[];
  const auditRows = audit.recordset as AuditRow[];
  const approved = coaches.filter((t) => t.ApprovalStatus === "Approved");
  return <div className="page-enter"><div className="page-heading"><div><p className="eyebrow">SYSTEM MANAGEMENT</p><h1>Care, <em>coordinated.</em></h1><p className="page-subtitle">Manage FitAI members, trainer applications and assignments.</p></div><form action={signOut}><button className="button button-dark">Sign out</button></form></div>
    <div className="metric-grid admin-metrics"><Metric title="USERS IN VIEW" value={rows.length}/><Metric title="TRAINERS" value={coaches.length}/><Metric title="PENDING REQUESTS" value={requestRows.filter((r) => r.RequestStatus === "Pending").length}/><Metric title="UNASSIGNED IN VIEW" value={rows.filter((r) => !r.Trainer).length}/></div>
    <section className="panel management-panel"><div className="panel-heading"><div><p className="eyebrow">CUSTOMER RELATIONSHIPS</p><h3>Users and assigned trainers</h3></div></div>
      <form className="admin-filters"><input name="q" defaultValue={query} placeholder="Search customer or email"/><select name="assignment" defaultValue={assignment}><option value="">All assignments</option><option value="Assigned">Assigned</option><option value="Unassigned">Unassigned</option></select><select name="trainer" defaultValue={trainerId}><option value="">All trainers</option>{coaches.map((t) => <option key={t.UserId} value={t.UserId}>{t.Name || t.Email}</option>)}</select><select name="request" defaultValue={requestStatus}><option value="">All requests</option>{["Pending", "Assigned", "Rejected", "Approved"].map((s) => <option key={s}>{s}</option>)}</select><button className="small-action">Filter</button></form>
      {rows.length ? <div className="table-wrap"><table><thead><tr><th>Customer</th><th>Customer email</th><th>Assigned trainer</th><th>Trainer email</th><th>Status</th><th>Assigned date</th><th>Actions</th></tr></thead><tbody>{rows.map((c) => <tr key={c.UserId}><td>{c.Customer || "FitAI member"}</td><td>{c.Email}</td><td>{c.Trainer || "—"}</td><td>{c.TrainerEmail || "—"}</td><td><span className="status-badge">{c.AssignmentStatus}</span></td><td>{c.AssignedDate ? new Date(c.AssignedDate).toLocaleDateString("en-IN") : "—"}</td><td>{approved.length ? <form action={assignTrainer} className="assign-form"><input type="hidden" name="userId" value={c.UserId}/><select name="trainerId" required defaultValue=""><option value="" disabled>{c.Trainer ? "Reassign…" : "Assign…"}</option>{approved.map((t) => <option key={t.UserId} value={t.UserId}>{t.Name || t.Email}</option>)}</select><ConfirmSubmit className="small-action" message={c.Trainer ? `Reassign ${c.Customer || c.Email} to the selected trainer?` : `Assign ${c.Customer || c.Email} to the selected trainer?`}>Save</ConfirmSubmit></form> : "No approved trainers"}</td></tr>)}</tbody></table></div> : <div className="empty-state">No customer accounts match these filters.</div>}
    </section>
    <div className="dashboard-lower admin-lower"><section className="panel management-panel"><p className="eyebrow">TRAINER APPLICATIONS</p><h3>Trainers</h3>{coaches.length ? coaches.map((t) => <div className="management-row" key={t.UserId}><div><strong>{t.Name || t.Email}</strong><small>{t.Email} · {t.Specialization}</small></div><span className="status-badge">{t.ApprovalStatus}</span>{t.ApprovalStatus === "Pending" && <form action={setTrainerApproval}><input type="hidden" name="trainerId" value={t.UserId}/><ConfirmSubmit className="small-action" name="status" value="Approved" message={`Approve ${t.Name || t.Email} as a trainer?`}>Approve</ConfirmSubmit><ConfirmSubmit className="small-action secondary" name="status" value="Rejected" message={`Reject ${t.Name || t.Email}'s trainer application?`}>Reject</ConfirmSubmit></form>}</div>) : <div className="empty-state">No trainer applications.</div>}</section>
      <section className="panel management-panel"><p className="eyebrow">TRAINER REQUESTS</p><h3>Member requests</h3>{requestRows.length ? requestRows.map((r) => <div className="management-row" key={r.TrainerRequestId}><div><strong>{r.DisplayName || r.Email}</strong><small>{r.Notes || "No additional notes"}</small></div><span className="status-badge">{r.RequestStatus}</span>{r.RequestStatus === "Pending" && <form action={rejectTrainerRequest}><input type="hidden" name="requestId" value={r.TrainerRequestId}/><ConfirmSubmit className="small-action secondary" message={`Reject ${r.DisplayName || r.Email}'s trainer request?`}>Reject</ConfirmSubmit></form>}</div>) : <div className="empty-state">No requests yet.</div>}</section></div>
    <section className="panel management-panel audit-panel"><p className="eyebrow">ADMINISTRATIVE HISTORY</p><h3>Recent actions</h3>{auditRows.length ? auditRows.map((e, i) => <div className="management-row" key={i}><div><strong>{e.EventType}</strong><small>{e.Details || ""}</small></div><small>{new Date(e.CreatedAtUtc).toLocaleString("en-IN")}</small></div>) : <div className="empty-state">Admin actions will appear here.</div>}</section>
  </div>;
}

function Metric({ title, value }: { title: string; value: number }) { return <article className="metric-card"><p className="metric-title">{title}</p><p className="metric-number">{value}</p></article>; }
