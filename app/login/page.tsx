import Link from "next/link";
import { LoginForm } from "@/components/auth-form";
import { currentUser, dashboardFor } from "@/lib/auth";
import { redirect } from "next/navigation";

export const instant = false;

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ registered?: string }> }) {
  const user = await currentUser(); if (user) redirect(dashboardFor(user.role));
  const { registered } = await searchParams;
  return <main className="auth-page"><Link href="/login" className="auth-brand">fit<span>ai</span></Link><section className="auth-card"><p className="eyebrow">YOUR WELLNESS, IN FOCUS</p><h1>Welcome <em>back.</em></h1><p className="auth-intro">Sign in to continue your FitAI journey.</p>{registered && <p className="success-message">Account created. You can sign in now.</p>}<LoginForm/></section><p className="auth-foot">Private by design · FitAI</p></main>;
}
