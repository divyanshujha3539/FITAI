"use client";

export function ConfirmSubmit({ children, message, className, name, value }: { children: React.ReactNode; message: string; className: string; name?: string; value?: string }) {
  return <button className={className} name={name} value={value} onClick={(event) => { if (!window.confirm(message)) event.preventDefault(); }}>{children}</button>;
}
