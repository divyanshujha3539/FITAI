import Link from "next/link";
import { RegisterForm } from "@/components/auth-form";
import { currentUser, dashboardFor } from "@/lib/auth";
import { redirect } from "next/navigation";

export const instant = false;

export default async function RegisterPage() {
  const user = await currentUser(); if (user) redirect(dashboardFor(user.role));
  return <main className="auth-page"><Link href="/login" className="auth-brand">fit<span>ai</span></Link><section className="auth-card auth-card-wide"><p className="eyebrow">A GOOD PLACE TO BEGIN</p><h1>Make it <em>yours.</em></h1><p className="auth-intro">Create a User or Trainer account. Administrator accounts are provisioned by the project owner.</p><RegisterForm/></section><p className="auth-foot">Private by design · FitAI</p></main>;
}
