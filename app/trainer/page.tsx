import { redirect } from "next/navigation";
import { currentUser, dashboardFor } from "@/lib/auth";
import { database, sql } from "@/lib/db";
import { signOut } from "@/app/actions/auth";
import { updateOwnProfile, updateTrainerProfile } from "@/app/actions/management";

export const instant = false;

export default async function TrainerHome() {
  const user = await currentUser(); if (!user) redirect("/login"); if (user.role !== "TRAINER") redirect(dashboardFor(user.role));
  const db = await database();
  const [profile, clients] = await Promise.all([
    db.request().input("id", sql.NVarChar(128), user.id).query("SELECT Specialization,ExperienceYears,ApprovalStatus FROM dbo.TrainerProfiles WHERE UserId=@id"),
    db.request().input("id", sql.NVarChar(128), user.id).query("SELECT p.DisplayName,u.Email,r.RequestStatus,a.AssignedAtUtc FROM dbo.TrainerAssignments a JOIN dbo.Users u ON u.UserId=a.UserId JOIN dbo.TrainerProfiles tp ON tp.UserId=a.TrainerId AND tp.ApprovalStatus='Approved' LEFT JOIN dbo.UserProfiles p ON p.UserId=u.UserId LEFT JOIN dbo.TrainerRequests r ON r.TrainerRequestId=a.TrainerRequestId WHERE a.TrainerId=@id AND a.EndedAtUtc IS NULL ORDER BY a.AssignedAtUtc DESC")
  ]);
  const t = profile.recordset[0];
  return <div className="page-enter"><div className="page-heading"><div><p className="eyebrow">TRAINER WORKSPACE</p><h1>Your coaching, <em>with care.</em></h1><p className="page-subtitle">Welcome, {user.name}. Here are your active customer relationships.</p></div><form action={signOut}><button className="button button-dark">Sign out</button></form></div><section className="panel trainer-profile"><p className="eyebrow">YOUR PROFILE · {t?.ApprovalStatus ?? "Pending"}</p><form action={updateOwnProfile} className="inline-form"><label>Full name<input name="name" required minLength={2} maxLength={100} defaultValue={user.name}/></label><button className="button button-dark">Save name</button></form><form action={updateTrainerProfile} className="inline-form"><label>Specialization<input name="specialization" required maxLength={300} defaultValue={t?.Specialization ?? ""}/></label><label>Phone<input name="phone" type="tel" maxLength={30}/></label><label>Experience in years<input name="experience" type="number" min="0" max="60" defaultValue={t?.ExperienceYears ?? ""}/></label><button className="button button-dark">Save trainer profile</button></form><p className="page-subtitle">New trainer accounts require admin approval before assignment. Profile edits cannot change your role or approval status.</p></section><section className="panel management-panel"><div className="panel-heading"><div><p className="eyebrow">CURRENT ASSIGNMENTS</p><h3>Your customers</h3></div><span className="step-count">{clients.recordset.length} assigned</span></div>{clients.recordset.length ? <div className="table-wrap"><table><thead><tr><th>Customer</th><th>Email</th><th>Assigned</th></tr></thead><tbody>{clients.recordset.map((c: { DisplayName: string | null; Email: string; AssignedAtUtc: Date }, i: number) => <tr key={i}><td>{c.DisplayName || "FitAI member"}</td><td>{c.Email}</td><td>{new Date(c.AssignedAtUtc).toLocaleDateString("en-IN")}</td></tr>)}</tbody></table></div> : <div className="empty-state"><strong>No assigned customers yet</strong><p>The admin will add approved customer relationships here.</p></div>}</section></div>;
}
