# FitAI

FitAI is a fitness and nutrition companion designed around student life in India. This first milestone establishes the Next.js App Router foundation, responsive navigation, dashboard and the route structure for the product areas.

## Run locally

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The root route redirects to the dashboard.

## Current milestone

The interface uses honest empty states. Nutrition, workout, profile, AI, gym and report routes are ready for their data and workflows to be added in later milestones. They do not yet save records or call external services.

The initial Azure SQL schema, ER diagram, migration, repeatable reference-data seed, sample reporting queries, and normalization/indexing notes are documented in [`docs/database.md`](docs/database.md). The scripts have not been run against a live database.

## Quality checks

```bash
npm run lint
npm run typecheck
npm run build
```

## Authentication and roles

The app supports `ADMIN`, `TRAINER`, and `USER` roles. User and Trainer accounts can register publicly. Trainer accounts start with `Pending` approval and cannot receive customer assignments until an admin approves them. Admin accounts cannot register publicly.

### Configure and migrate

1. Copy `.env.example` to `.env.local` and replace every placeholder. Keep `.env.local` out of source control. `SESSION_SECRET` must be a randomly generated value with at least 32 characters. The Azure SQL login needs permission to run the migrations and normal application queries.
2. Apply `db/migrations/001_initial_schema.sql`, then `db/migrations/002_role_auth_and_assignments.sql` to the intended Azure SQL database. Migration 002 adds password hashes to the existing identity table and creates role, trainer profile, request, assignment history, and audit tables. Both are additive; neither drops existing data.
3. Set `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD` before the first Admin sign-in. The app provisions that account on an Admin sign-in only if the configured email does not already exist. It hashes the password and assigns `ADMIN` on the server. Bootstrap does not overwrite existing accounts or reset passwords after restart. If the email already belongs to another role, bootstrap does not promote it; choose a fresh owner-controlled email or securely correct the account directly in the database.
4. To rotate the administrator password, change it through a future owner-only password-management process or update its bcrypt hash through a controlled database operation. Changing `INITIAL_ADMIN_PASSWORD` does not rotate a provisioned password. To rotate sessions, replace `SESSION_SECRET`; this signs out all current sessions.

### Assignment workflow

Members submit a trainer request. The admin approves trainer applications and makes the final assignment or reassignment. The assignment write uses a serializable transaction and the database has a unique filtered index allowing only one active assignment per member; ended assignment rows preserve history. Trainers can see only their active assigned customers. Admin assignment changes and trainer approval/rejection are written to `AdminAuditEvents`.

Email verification, trainer/member messaging, profile editing, account disabling, and fitness-record persistence are not implemented. Existing feature routes remain honest placeholder screens; this authentication milestone does not connect AI, nutrition, or workouts to live private records. Azure SQL has not been configured or migrated in this workspace, and no administrator has been provisioned here.

### Test each role

After configuring Azure SQL and applying both migrations, start the app with `npm run dev`. Create a User and Trainer through `/register`; sign in from `/login` with each matching role. Set the owner bootstrap variables and select Admin on `/login` to provision and enter `/admin`. Trainer accounts need admin approval before they appear as assignment choices. An account selected under the wrong login role receives a generic credential/role mismatch error.
