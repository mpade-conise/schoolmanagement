import { useEffect, useMemo, useState } from "react";
import { Activity, ArrowUpRight, Bell, ChevronDown, ChevronLeft, ChevronRight, CircleHelp, LayoutDashboard, LogOut, Menu, Search, ShieldCheck, X } from "lucide-react";
import { supabase } from "../../../lib/supabase";
import coneduLogo from "../../../assets/conedu-logo.svg";
import { adminGroups, allAdminModules, type AdminModule } from "./modules";
import StudentManagement from "./StudentManagement";
import StaffManagement from "./StaffManagement";
import ClassesSubjects from "./ClassesSubjects";
import AcademicCalendar from "./AcademicCalendar";
import AttendanceManagement from "./AttendanceManagement";
import ExaminationsResults from "./ExaminationsResults";
import TimetableManagement from "./TimetableManagement";
import FeesPayments from "./FeesPayments";
import SchoolReports from "./SchoolReports";
import "./administration.css";

type Props = { schoolId: string; schoolName: string; role?: string };
type Counts = { students: number; staff: number; classes: number; attendance: number };
const emptyCounts: Counts = { students: 0, staff: 0, classes: 0, attendance: 0 };

export default function SecondaryAdministration({ schoolId, schoolName, role = "school_admin" }: Props) {
 const [active, setActive] = useState("overview");
 const [mobileOpen, setMobileOpen] = useState(false);
 const [query, setQuery] = useState("");
 const [counts, setCounts] = useState<Counts>(emptyCounts);
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState("");
 const roleModules = role === "academic_officer" ? new Set(["students","classes","academic-calendar","attendance","exams","timetable","reports"]) : role === "bursar" ? new Set(["fees","reports"]) : null;
 const filteredGroups = useMemo(() => adminGroups.map(group => ({ ...group, items: group.items.filter(item => (!roleModules || roleModules.has(item.id)) && (item.title + " " + item.description + " " + item.features.join(" ")).toLowerCase().includes(query.toLowerCase())) })).filter(group => group.items.length), [query, role]);
 const selected = allAdminModules.find(module => module.id === active);
 useEffect(() => {
  let alive = true;
  async function load() {
   if (!supabase) { setLoading(false); setError("Supabase is not configured."); return; }
   setLoading(true); setError("");
   const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Blantyre", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
   const results = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
    supabase.from("staff_profiles").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("is_active", true),
    supabase.from("classes").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("is_active", true),
    supabase.from("attendance_sessions").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("attendance_date", today)
   ]);
   const issue = results.find(result => result.error)?.error;
   if (!alive) return;
   if (issue) { setError(issue.message); setCounts(emptyCounts); }
   else setCounts({ students: results[0].count || 0, staff: results[1].count || 0, classes: results[2].count || 0, attendance: results[3].count || 0 });
   setLoading(false);
  }
  void load();
  return () => { alive = false; };
 }, [schoolId]);
 const openModule = (id: string) => { setActive(id); setMobileOpen(false); };
 const dateLabel = new Intl.DateTimeFormat("en-MW", { timeZone: "Africa/Blantyre", weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(new Date());
 const statCards = [{ label: "Students", value: counts.students, id: "students", note: "Registered student records" }, { label: "Active staff", value: counts.staff, id: "staff", note: "Active staff profiles" }, { label: "Active classes", value: counts.classes, id: "classes", note: "Currently active classes" }, { label: "Attendance sessions", value: counts.attendance, id: "attendance", note: "Sessions recorded today" }];
 return <div className="sec-admin">
  <aside className={mobileOpen ? "sec-admin-sidebar open" : "sec-admin-sidebar"}>
   <div className="sec-admin-brand"><img src={coneduLogo} alt="ConEdu"/><div><strong>ConEdu</strong><span>SECONDARY ADMIN</span></div><button className="sec-icon-btn sec-mobile-close" onClick={() => setMobileOpen(false)} aria-label="Close menu"><X size={18}/></button></div>
   <div className="sec-school-chip"><div className="sec-school-mark">{schoolName.slice(0,1).toUpperCase() || "S"}</div><div><strong>{schoolName}</strong><span>School administration</span></div><ChevronDown size={15}/></div>
   <div className="sec-admin-nav">
    <button className={active === "overview" ? "sec-nav-item active" : "sec-nav-item"} onClick={() => openModule("overview")}><LayoutDashboard size={17}/><span>Overview</span></button>
    {filteredGroups.map(group => <section className="sec-nav-group" key={group.title}><p>{group.title}</p>{group.items.map(item => { const Icon = item.icon; return <button key={item.id} className={active === item.id ? "sec-nav-item active" : "sec-nav-item"} onClick={() => openModule(item.id)}><Icon size={17}/><span>{item.title}</span></button>; })}</section>)}
   </div>
   <div className="sec-admin-sidebar-bottom"><div className="sec-admin-help"><CircleHelp size={17}/><strong>Administration guide</strong><span>School management workspace</span></div><button className="sec-admin-signout" onClick={() => supabase?.auth.signOut()}><LogOut size={16}/> Sign out</button></div>
  </aside>
  {mobileOpen && <button className="sec-admin-backdrop" onClick={() => setMobileOpen(false)} aria-label="Close sidebar"/>}
  <main className="sec-admin-main">
   <header className="sec-admin-topbar"><button className="sec-icon-btn sec-mobile-open" onClick={() => setMobileOpen(true)} aria-label="Open sidebar"><Menu size={19}/></button><div className="sec-admin-breadcrumb"><span>Secondary school</span><ChevronRight size={14}/><strong>{selected?.title || "Administration overview"}</strong></div><div className="sec-admin-top-actions"><div className="sec-admin-search"><Search size={16}/><input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search administration modules" aria-label="Search administration modules"/></div><button className="sec-icon-btn" aria-label="Notifications" disabled title="Notifications will be connected in the communications module"><Bell size={18}/></button><span className="sec-admin-role"><ShieldCheck size={15}/> Administrator</span></div></header>
   <div className="sec-admin-content">
    {active === "students" ? <StudentManagement schoolId={schoolId} canEdit={["school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "staff" ? <StaffManagement schoolId={schoolId} canEdit={["school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "classes" ? <ClassesSubjects schoolId={schoolId} canEdit={["school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "academic-calendar" ? <AcademicCalendar schoolId={schoolId} canEdit={["school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "attendance" ? <AttendanceManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","academic_officer"].includes(role)} onBack={() => openModule("overview")} /> : active === "exams" ? <ExaminationsResults schoolId={schoolId} canManage={["owner","school_admin","headteacher"].includes(role)} canReview={["owner","school_admin","headteacher"].includes(role)} canEnterMarks={["owner","school_admin","headteacher","deputy_headteacher","academic_officer","teacher","class_teacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "timetable" ? <TimetableManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "fees" ? <FeesPayments schoolId={schoolId} canEdit={["owner","school_admin","bursar"].includes(role)} onBack={() => openModule("overview")} /> : active === "reports" ? <SchoolReports schoolId={schoolId} role={role} onBack={() => openModule("overview")} /> : active === "overview" ? <><div className="sec-admin-welcome"><div><div className="sec-admin-eyebrow"><span/> SCHOOL ADMINISTRATION</div><h1>Administration overview</h1><p>Manage school operations, academic activities, people and resources from one workspace.</p></div><div className="sec-admin-date"><Activity size={15}/>{dateLabel}</div></div>
     {error && <div className="sec-admin-error" role="alert"><strong>Live data unavailable</strong><span>{error}. Dashboard values are not replaced with sample data.</span></div>}
     <div className="sec-admin-stats">{statCards.map(card => <button className="sec-admin-stat" key={card.id} onClick={() => openModule(card.id)}><span>{card.label}</span><strong>{loading ? "—" : card.value.toLocaleString()}</strong><small>{card.note}</small><ArrowUpRight size={16}/></button>)}</div>
     <section className="sec-admin-section-head"><div><h2>Administration modules</h2><p>Open a module to review its functions and implementation status.</p></div><span>{allAdminModules.length} modules</span></section>
     <div className="sec-admin-module-grid">{filteredGroups.flatMap(group => group.items).map(module => <ModuleCard key={module.id} module={module} onOpen={() => openModule(module.id)}/>)}</div>
     <div className="sec-admin-note"><ShieldCheck size={17}/><p><strong>Access and data protection</strong><span>Only authorised school leadership should access this portal. Supabase Row Level Security must enforce school and role permissions on every database operation.</span></p></div>
    </> : selected ? <ModulePage module={selected} onBack={() => openModule("overview")}/> : <div className="sec-admin-empty"><h2>No matching modules</h2><p>Try a different search term.</p><button onClick={() => setQuery("")}>Clear search</button></div>}
    <footer className="sec-admin-footer">ConEdu · Secondary school administration <span>Live school data · No demo records</span></footer>
   </div>
  </main>
 </div>;
}

function ModuleCard({ module, onOpen }: { module: AdminModule; onOpen: () => void }) {
 const Icon = module.icon;
 return <button className="sec-admin-module-card" onClick={onOpen}><span className="sec-admin-module-icon"><Icon size={19}/></span><strong>{module.title}</strong><p>{module.description}</p><span className="sec-admin-module-footer"><span>Feature catalogue</span><ArrowUpRight size={15}/></span></button>;
}
function ModulePage({ module, onBack }: { module: AdminModule; onBack: () => void }) {
 const Icon = module.icon;
 return <section className="sec-admin-module-page"><button className="sec-admin-back" onClick={onBack}><ChevronLeft size={16}/> Administration overview</button><div className="sec-admin-module-title"><span className="sec-admin-module-icon"><Icon size={22}/></span><div><div className="sec-admin-eyebrow"><span/> ADMINISTRATION MODULE</div><h1>{module.title}</h1><p>{module.description}</p></div></div><div className="sec-admin-status"><span className="sec-admin-status-dot"/> Feature scope defined <span>·</span> Database workflows will be connected in implementation stages</div><h2>Included features</h2><div className="sec-admin-feature-grid">{module.features.map((feature, index) => <div className="sec-admin-feature" key={feature}><span>{String(index + 1).padStart(2, "0")}</span><p>{feature}</p></div>)}</div><div className="sec-admin-implementation"><strong>Implementation status</strong><p>This page defines the administration features. Data entry, editing, approvals and reports will be enabled when this module's database tables, validation and role-specific RLS policies are implemented. No sample records are shown.</p></div></section>;
}
