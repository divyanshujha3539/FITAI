export type Role = "ADMIN" | "TRAINER" | "USER";
export type PublicRegistrationRole = Exclude<Role, "ADMIN">;

export function dashboardFor(role: Role) {
  return role === "ADMIN" ? "/admin" : role === "TRAINER" ? "/trainer" : "/user";
}

export function isPublicRegistrationRole(value: string): value is PublicRegistrationRole {
  return value === "USER" || value === "TRAINER";
}
