# Product architecture and delivery plan

## Product principles

1. **Multi-school SaaS from day one.** Every school owns its data through a tenant boundary; school-specific settings and academic records are not shared.
2. **Least privilege.** Access is controlled by active membership and school role. RLS remains enabled for exposed tables.
3. **Secondary-school focused, Malawi-first, configurable.** Defaults use Malawi, Africa/Blantyre and MWK, while schools can configure timezone, currency and academic calendar.
4. **Operationally reliable.** Preserve historical academic records; prefer status changes and archive workflows over deleting important records.
5. **Sellable and maintainable.** Consistent navigation, responsive layouts, validation, clear empty states, auditability, backup/recovery and documented deployment.
6. **Incremental delivery.** Build and verify one working module at a time without disrupting completed modules.

## Initial roles

- Owner: account ownership and school-wide administration
- School administrator: school configuration and staff access
- Headteacher: academic oversight and school reports
- Bursar: fees, payments and finance reports
- Registrar: learner admission and enrollment
- Teacher: assigned classes, subjects and attendance
- Parent/guardian: linked learner information and notices
- Student: permitted personal learning information

Permissions will be refined per module; role names alone must not bypass tenant isolation.

## Database foundation

The initial schema includes profiles, schools, memberships, academic years, terms, grade levels, classes, subjects, class-subject assignments, staff profiles, learners, enrollments, guardians, guardian links, attendance sessions and attendance records.

All application tables have RLS enabled. Authorization helper functions are in a non-exposed `private` schema. Composite foreign keys enforce that linked academic records belong to the same school.

## Delivery sequence

1. Database foundation and secure school onboarding
2. Frontend scaffold, authentication and school selection
3. School setup wizard and role-based dashboard
4. Learner, staff and class management
5. Attendance workflow and reports
6. Assessments, grading and report cards
7. Fees, billing, receipts and reconciliation
8. Parent/student portals, notifications and audit/reporting
9. Multi-school pilot, security review, backups and production deployment

## Release quality checklist

- Tenant isolation and RLS tests for every role
- Form validation and duplicate prevention
- Responsive desktop/mobile layouts
- Loading, empty, error and success states
- Accessible labels, keyboard navigation and readable contrast
- Malawi date, phone, currency and academic-calendar handling
- No secrets in client bundles or source control
- Verified backup/restore and documented support process
