import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";

export async function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const token = request.cookies.get("fitai_session")?.value;
  if (!token) return NextResponse.redirect(new URL("/login", request.url));
  try {
    const secret = process.env.SESSION_SECRET;
    if (!secret || secret.length < 32) throw new Error("Invalid session configuration");
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret), { algorithms: ["HS256"] });
    const targetRole = path.startsWith("/admin") ? "ADMIN" : path.startsWith("/trainer") ? "TRAINER" : "USER";
    if (!payload.sub || payload.role !== targetRole) return NextResponse.redirect(new URL("/login?role=incorrect", request.url));
    return NextResponse.next();
  } catch { return NextResponse.redirect(new URL("/login?expired=1", request.url)); }
}

export const config = { matcher: ["/dashboard/:path*", "/meals/:path*", "/analyzer/:path*", "/foods/:path*", "/optimizer/:path*", "/simulator/:path*", "/workouts/:path*", "/reports/:path*", "/memory/:path*", "/gyms/:path*", "/profile/:path*", "/user/:path*", "/trainer/:path*", "/admin/:path*"] };
