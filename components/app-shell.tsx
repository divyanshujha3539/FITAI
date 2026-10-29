"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, type ReactNode } from "react";
import { Icon } from "@/components/icon";
import { signOut } from "@/app/actions/auth";

type NavItem = { href: string; label: string; icon: "dashboard" | "meal" | "spark" | "food" | "wallet" | "dumbbell" | "chart" | "brain" | "pin" | "user" | "clock"; badge?: string };
type NavGroup = { label: string; items: NavItem[] };

const groups: NavGroup[] = [
  { label: "OVERVIEW", items: [{ href: "/dashboard", label: "Dashboard", icon: "dashboard" as const }] },
  { label: "NUTRITION", items: [
    { href: "/meals", label: "Meal tracker", icon: "meal" as const },
    { href: "/analyzer", label: "AI meal analyzer", icon: "spark" as const, badge: "AI" },
    { href: "/foods", label: "Food catalogue", icon: "food" as const },
    { href: "/optimizer", label: "Budget optimizer", icon: "wallet" as const },
    { href: "/simulator", label: "What-if simulator", icon: "chart" as const },
  ] },
  { label: "TRAINING", items: [
    { href: "/workouts", label: "Workout planner", icon: "dumbbell" as const },
    { href: "/workouts/history", label: "Workout history", icon: "clock" as const },
    { href: "/reports", label: "Progress reports", icon: "chart" as const },
  ] },
  { label: "YOUR SPACE", items: [
    { href: "/memory", label: "Fitness memory", icon: "brain" as const },
    { href: "/gyms", label: "Nearby gyms", icon: "pin" as const },
    { href: "/profile", label: "Profile & settings", icon: "user" as const },
  ] },
];
const adminGroups: NavGroup[] = [{ label: "MANAGEMENT", items: [{ href: "/admin", label: "Overview", icon: "dashboard" }] }];
const trainerGroups: NavGroup[] = [{ label: "COACHING", items: [{ href: "/trainer", label: "My customers", icon: "user" }] }];

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  if (pathname === "/login" || pathname === "/register") return <>{children}</>;
  const visibleGroups = pathname.startsWith("/admin") ? adminGroups : pathname.startsWith("/trainer") ? trainerGroups : groups;
  const dashboardHref = pathname.startsWith("/admin") ? "/admin" : pathname.startsWith("/trainer") ? "/trainer" : "/user";
  const activeItem = visibleGroups.flatMap(group => group.items).filter(item => pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(`${item.href}/`))).sort((a, b) => b.href.length - a.href.length)[0];
  const title = activeItem?.label ?? "Dashboard";
  return <div className="app-frame">
    {mobileOpen && <button className="mobile-scrim" aria-label="Close navigation" onClick={() => setMobileOpen(false)} />}
    <aside className={`sidebar ${mobileOpen ? "sidebar-open" : ""}`}>
      <Link className="brand" href={dashboardHref} onClick={() => setMobileOpen(false)}>
        <span className="brand-mark"><span /></span><span className="brand-name">fit<span>ai</span><small>STUDENT WELLNESS</small></span>
      </Link>
      <div className="campus-pill"><span className="pulse-dot" /> YOUR PERSONAL SPACE</div>
      <nav className="side-nav" aria-label="Main navigation">
        {visibleGroups.map(group => <div className="nav-group" key={group.label}><p>{group.label}</p>{group.items.map(item => {
          const active = item.href === "/dashboard" ? pathname === "/dashboard" : pathname === item.href || pathname.startsWith(`${item.href}/`);
          return <Link href={item.href} key={item.href} onClick={() => setMobileOpen(false)} className={`nav-link ${active ? "active" : ""}`} aria-current={active ? "page" : undefined}>
            <Icon name={item.icon} size={18} /><span>{item.label}</span>{"badge" in item && <small>{item.badge}</small>}
          </Link>;
        })}</div>)}
      </nav>
      <div className="sidebar-bottom"><div className="sidebar-note"><span className="note-spark">✳</span><strong>Small steps add up.</strong><p>Your routine is yours. Build it one day at a time.</p></div><span className="version">FITAI · STUDENT PROJECT</span></div>
    </aside>
    <section className="workspace">
      <header className="topbar">
        <div className="topbar-left"><button className="mobile-menu icon-button" aria-label="Open navigation" onClick={() => setMobileOpen(true)}><Icon name="menu" /></button><span className="breadcrumb-muted">Workspace</span><Icon name="chevron" size={15} /><span className="breadcrumb-current">{title}</span></div>
        <div className="topbar-right"><span className="today-label">A little progress, every day</span>{dashboardHref === "/user" && <Link className="top-profile" href="/profile" aria-label="Open profile and settings"><span className="profile-dot">✳</span><Icon name="chevron" size={14} /></Link>}<form action={signOut}><button className="shell-signout">Sign out</button></form></div>
      </header>
      <main className="main-content">{children}</main>
    </section>
  </div>;
}
