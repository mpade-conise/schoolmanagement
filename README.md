# School Management System

A secure, multi-school management platform designed specifically for secondary schools in Malawi.

## Product direction

This is a multi-tenant SaaS product: each school has its own isolated records, settings, staff, learners, academic calendar and reports. A school must never access another school's data.

### Product scope

ConEdu currently supports secondary schools only. Primary-school pages and workflows have been removed to keep the product focused and easier to use.

## Planned modules

- School setup, onboarding and staff access
- Academic years, terms, forms, classes and subjects
- Learner admissions, enrollment and guardian contacts
- Staff directory and teaching assignments
- Daily attendance and attendance summaries
- Assessments, grading, report cards and transcript history
- Fee structures, invoices, receipts, balances and financial reports
- Parent/guardian communication and learner/parent portals
- Dashboard, exports, audit trail and school settings

## Technology

- Supabase (PostgreSQL, Auth and Storage)
- React + TypeScript frontend (implementation to follow)
- Vercel deployment (implementation to follow)

## Data and security

The school database is a separate Supabase project and is not connected to the Con-Bus / marketplace database.

- School records are scoped by `school_id`.
- Row Level Security is enabled on all application tables.
- Access is based on active school membership and role.
- Public frontend code must use only the publishable/anon key; never expose a service-role key.
- Sensitive student data should be collected only when needed and protected by role-based access.

## Development status

**Foundation phase:** core multi-school database, school memberships, academic structure, learners, guardians, staff assignments and attendance have been provisioned. Frontend, onboarding, assessments, fees and reporting are planned next.

## Local development

Setup instructions will be added when the frontend scaffold is committed. Do not add production secrets to the repository; use environment variables and the hosting provider's secret store.
