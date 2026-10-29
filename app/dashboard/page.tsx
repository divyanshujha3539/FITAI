import Link from "next/link";
import { Icon } from "@/components/icon";

const days = ["M", "T", "W", "T", "F", "S", "S"];

export default function DashboardPage() {
  return <div className="page-enter dashboard-page">
    <div className="page-heading dashboard-heading"><div><p className="eyebrow">THURSDAY, OCTOBER 29</p><h1>Your day, <em>your pace.</em></h1><p className="page-subtitle">A little structure can make a big difference. Start wherever you are.</p></div><Link className="button button-dark" href="/meals"><Icon name="plus" size={17} /> Log a meal</Link></div>

    <section className="welcome-card">
      <div className="welcome-copy"><span className="welcome-kicker"><span className="pulse-dot" /> YOUR WELLNESS SNAPSHOT</span><h2>Make room for<br/><em>feeling good.</em></h2><p>Track meals, find a routine that fits student life, and keep your goals within reach.</p><div className="welcome-actions"><Link href="/profile" className="button button-light">Set up your profile <Icon name="arrow" size={16}/></Link><Link href="/analyzer" className="text-link-light"><Icon name="spark" size={16}/> Try AI meal analyzer</Link></div></div>
      <div className="welcome-art" aria-hidden="true"><div className="art-sun"/><div className="art-ring ring-one"/><div className="art-ring ring-two"/><div className="art-orbit"><span className="orbit-star">✳</span><span className="orbit-dot"/></div><div className="art-leaf leaf-one"/><div className="art-leaf leaf-two"/><div className="art-caption">A GOOD DAY<br/>STARTS SMALL</div></div>
      <div className="welcome-index">01 <span>/ 03</span></div>
    </section>

    <section className="metric-grid" aria-label="Today's nutrition summary">
      <Metric title="ENERGY" unit="kcal" detail="Daily target not set" icon="spark" color="peach" />
      <Metric title="PROTEIN" unit="g" detail="Daily target not set" icon="meal" color="sage" />
      <Metric title="WATER" unit="glasses" detail="Start tracking today" icon="food" color="blue" />
      <Metric title="MOVEMENT" unit="sessions" detail="Your activity, over time" icon="dumbbell" color="lilac" />
    </section>

    <div className="dashboard-lower">
      <section className="panel trend-panel"><div className="panel-heading"><div><p className="eyebrow">YOUR RHYTHM</p><h3>A week in view</h3></div><Link className="quiet-link" href="/reports">View reports <Icon name="arrow" size={15}/></Link></div><div className="chart-empty"><div className="chart-grid-lines"><i/><i/><i/><i/></div><div className="chart-empty-center"><span className="chart-icon"><Icon name="chart" size={22}/></span><strong>Your story starts here</strong><p>Log a meal or workout to see your week take shape.</p></div><div className="chart-days">{days.map((day, i) => <span key={i}>{day}</span>)}</div></div></section>
      <section className="panel next-panel"><div className="panel-heading"><div><p className="eyebrow">A GOOD PLACE TO BEGIN</p><h3>Your next steps</h3></div><span className="step-count">0 / 3</span></div><div className="step-list"><Step href="/profile" n="01" title="Make it yours" text="Set your goals and preferences."/><Step href="/meals" n="02" title="Log your first meal" text="Start with whatever you had today."/><Step href="/workouts" n="03" title="Find your movement" text="Build a plan that fits your week."/></div></section>
    </div>
    <div className="privacy-strip"><span className="privacy-icon">✳</span><p><strong>Your data stays yours.</strong> FitAI is being built with privacy at its core. Your personal records will only be visible to you.</p><Link href="/profile">Learn about your account <Icon name="arrow" size={14}/></Link></div>
  </div>;
}

function Metric({ title, unit, detail, icon, color }: { title: string; unit: string; detail: string; icon: "spark" | "meal" | "food" | "dumbbell"; color: string }) {
  return <article className="metric-card"><div className={`metric-icon ${color}`}><Icon name={icon} size={17}/></div><p className="metric-title">{title}</p><p className="metric-number">— <span>{unit}</span></p><p className="metric-detail">{detail}</p><div className="metric-track"><span/></div></article>;
}

function Step({ href, n, title, text }: { href: string; n: string; title: string; text: string }) {
  return <Link className="step-item" href={href}><span className="step-number">{n}</span><span className="step-copy"><strong>{title}</strong><small>{text}</small></span><Icon name="arrow" size={16}/></Link>;
}
