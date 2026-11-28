import { useMemo, useState } from "react";
import { Bell, GraduationCap, ChevronDown, ChevronLeft, ChevronRight, CircleHelp, LayoutDashboard, LogOut, Menu, Search, ShieldCheck, X } from "lucide-react";
import { supabase } from "../../../lib/supabase";
import coneduLogo from "../../../assets/conedu-logo.svg";
import { allAdminModules, type AdminModule } from "./modules";
import StudentManagement from "./StudentManagement";
import StaffManagement from "./StaffManagement";
import AcademicStructureWorkspace from "./AcademicStructureWorkspace";
import AcademicCalendar from "./AcademicCalendar";
import AttendanceManagement from "./AttendanceManagement";
import ExaminationsResults from "./ExaminationsResults";
import TimetableManagement from "./TimetableManagement";
import FeesPayments from "./FeesPayments";
import SchoolReports from "./SchoolReports";
import UserAccess from "./UserAccess";
import GuardiansManagement from "./GuardiansManagement";
import DisciplineWelfare from "./DisciplineWelfare";
import Communication from "./Communication";
import LibraryManagement from "./LibraryManagement";
import InventoryManagement from "./InventoryManagement";
import AdministrationDashboard from "./AdministrationDashboard";
import EventsManagement from "./EventsManagement";
import StaffAttendance from "./StaffAttendance";
import StudentDocuments from "./StudentDocuments";
import "./administration.css";

type Props = { schoolId: string; schoolName: string; role?: string };

export default function SecondaryAdministration({ schoolId, schoolName, role = "school_admin" }: Props) {
 const [active, setActive] = useState("overview");
 const [studentSection,setStudentSection]=useState("records");
 const [mobileOpen, setMobileOpen] = useState(false);
 const [query, setQuery] = useState("");
 const roleModules = role === "academic_officer" ? new Set(["students","classes","academic-calendar","attendance","exams","timetable","reports","discipline","communications","library","events"]) : role === "bursar" ? new Set(["fees","reports"]) : null;
 const filteredModules = useMemo(() => allAdminModules.filter(item => (!roleModules || roleModules.has(item.id)) && (item.id !== "students" && item.id !== "accounts" || ["owner","school_admin","headteacher"].includes(role)) && (item.title + " " + item.description + " " + item.features.join(" ")).toLowerCase().includes(query.toLowerCase())), [query, role]);
 const studentTabs = useMemo(() => [{key:"records",label:"Student register"},{key:"profiles",label:"Student profiles"},{key:"admission",label:"Admissions & numbers"},{key:"placement",label:"Class & stream placement"},{key:"progression",label:"Transfers & promotion"},{key:"status",label:"Status & archives"},{key:"attendance",label:"Attendance history"},{key:"results",label:"Examination results"},{key:"fees",label:"Fee payment history"},{key:"discipline",label:"Discipline records"},{key:"medical",label:"Medical & emergency info"},{key:"documents",label:"Student documents"},{key:"previous-school",label:"Previous school"},{key:"id-cards",label:"Student ID cards"},{key:"import-export",label:"Excel / CSV import & export"}].filter(item => item.label.toLowerCase().includes(query.toLowerCase())), [query]);
 const selected = allAdminModules.find(module => module.id === active);

 const openModule = (id: string) => { setActive(id); setMobileOpen(false); };
 return <div className="sec-admin">
  <aside className={mobileOpen ? "sec-admin-sidebar open" : "sec-admin-sidebar"}>
   <div className="sec-admin-brand"><img src={coneduLogo} alt="ConEdu"/><div><strong>ConEdu</strong><span>SECONDARY ADMIN</span></div><button className="sec-icon-btn sec-mobile-close" onClick={() => setMobileOpen(false)} aria-label="Close menu"><X size={18}/></button></div>
   <div className="sec-school-chip"><div className="sec-school-mark">{schoolName.slice(0,1).toUpperCase() || "S"}</div><div><strong>{schoolName}</strong><span>School administration</span></div><ChevronDown size={15}/></div>
   <div className="sec-admin-nav">
    <button className={active === "overview" ? "sec-nav-item active" : "sec-nav-item"} onClick={() => openModule("overview")}><LayoutDashboard size={17}/><span>Overview</span></button>
    <button className={active === "students" && studentSection === "records" ? "sec-nav-item active" : "sec-nav-item"} onClick={() => { setStudentSection("records"); openModule("students"); }}><GraduationCap size={17}/><span>Student management</span></button>
    {studentTabs.map(item => <button key={item.key} className={active === "students" && studentSection === item.key ? "sec-nav-item active" : "sec-nav-item"} onClick={() => { setStudentSection(item.key); openModule("students"); }}><GraduationCap size={17}/><span>{item.label}</span></button>)}
    {filteredModules.map(item => { const Icon = item.icon; return <button key={item.id} className={active === item.id ? "sec-nav-item active" : "sec-nav-item"} onClick={() => openModule(item.id)}><Icon size={17}/><span>{item.title}</span></button>; })}
   </div>
   <div className="sec-admin-sidebar-bottom"><div className="sec-admin-help"><CircleHelp size={17}/><strong>Administration guide</strong><span>School management workspace</span></div><button className="sec-admin-signout" onClick={() => supabase?.auth.signOut()}><LogOut size={16}/> Sign out</button></div>
  </aside>
  {mobileOpen && <button className="sec-admin-backdrop" onClick={() => setMobileOpen(false)} aria-label="Close sidebar"/>}
  <main className="sec-admin-main">
   <header className="sec-admin-topbar"><button className="sec-icon-btn sec-mobile-open" onClick={() => setMobileOpen(true)} aria-label="Open sidebar"><Menu size={19}/></button><div className="sec-admin-breadcrumb"><span>Secondary school</span><ChevronRight size={14}/><strong>{selected?.title || "Administration overview"}</strong></div><div className="sec-admin-top-actions"><div className="sec-admin-search"><Search size={16}/><input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search administration modules" aria-label="Search administration modules"/></div><button className="sec-icon-btn" aria-label="Announcements" onClick={() => openModule("communications")} title="Open school announcements"><Bell size={18}/></button><span className="sec-admin-role"><ShieldCheck size={15}/> Administrator</span></div></header>
   <div className="sec-admin-content">
    {active === "students" ? (studentSection==="guardians"?<GuardiansManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","registrar"].includes(role)} canInvite={role==="school_admin"} onBack={()=>openModule("students")}/>:studentSection==="attendance"?<AttendanceManagement schoolId={schoolId} canEdit={false} onBack={()=>openModule("students")}/>:studentSection==="results"?<ExaminationsResults schoolId={schoolId} canManage={["owner","school_admin","headteacher"].includes(role)} canReview={["owner","school_admin","headteacher"].includes(role)} canEnterMarks={false} onBack={()=>openModule("students")}/>:studentSection==="fees"?<FeesPayments schoolId={schoolId} canEdit={["owner","school_admin","bursar"].includes(role)} onBack={()=>openModule("students")}/>:studentSection==="discipline"?<DisciplineWelfare schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","academic_officer"].includes(role)} canDelete={["owner","school_admin","headteacher"].includes(role)} onBack={()=>openModule("students")}/>:studentSection==="documents"?<StudentDocuments schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} onBack={()=>openModule("students")}/>:<StudentManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} canInvite={role==="school_admin"} section={studentSection} onBack={() => openModule("overview")} />) : active === "staff" ? <StaffManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} canManagePayroll={["owner","school_admin"].includes(role)} onBack={() => openModule("overview")} /> : active === "staff-attendance" ? <StaffAttendance schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","bursar"].includes(role)} onBack={() => openModule("overview")} /> : active === "classes" ? <AcademicStructureWorkspace schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "academic-calendar" ? <AcademicCalendar schoolId={schoolId} canEdit={["owner","proprietor","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "attendance" ? <AttendanceManagement schoolId={schoolId} canEdit={false} onBack={() => openModule("overview")} /> : active === "exams" ? <ExaminationsResults schoolId={schoolId} canManage={["owner","school_admin","headteacher"].includes(role)} canReview={["owner","school_admin","headteacher"].includes(role)} canEnterMarks={["owner","school_admin","headteacher","deputy_headteacher","academic_officer","teacher","class_teacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "timetable" ? <TimetableManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "fees" ? <FeesPayments schoolId={schoolId} canEdit={["owner","school_admin","bursar"].includes(role)} onBack={() => openModule("overview")} /> : active === "reports" ? <SchoolReports schoolId={schoolId} role={role} onBack={() => openModule("overview")} /> : active === "accounts" ? <UserAccess schoolId={schoolId} role={role} canEdit={["owner","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "guardians" ? <GuardiansManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","registrar"].includes(role)} canInvite={role==="school_admin"} onBack={() => openModule("overview")} /> : active === "discipline" ? <DisciplineWelfare schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","academic_officer"].includes(role)} canDelete={["owner","school_admin","headteacher"].includes(role)} onBack={() => openModule("overview")} /> : active === "communications" ? <Communication schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","academic_officer"].includes(role)} onBack={() => openModule("overview")} /> : active === "library" ? <LibraryManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","academic_officer"].includes(role)} onBack={() => openModule("overview")} /> : active === "inventory" ? <InventoryManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","deputy_headteacher","bursar"].includes(role)} onBack={() => openModule("overview")} /> : active === "events" ? <EventsManagement schoolId={schoolId} canEdit={["owner","school_admin","headteacher","academic_officer"].includes(role)} onBack={() => openModule("overview")} /> : active === "overview" ? <AdministrationDashboard schoolId={schoolId} role={role} onOpen={openModule}/> : selected ? <ModulePage module={selected} onBack={() => openModule("overview")}/> : <div className="sec-admin-empty"><h2>No matching modules</h2><p>Try a different search term.</p><button onClick={() => setQuery("")}>Clear search</button></div>}
    <footer className="sec-admin-footer">ConEdu · Secondary school administration <span>Live school data · No demo records</span></footer>
   </div>
  </main>
 </div>;
}

function ModulePage({ module, onBack }: { module: AdminModule; onBack: () => void }) {
 const Icon = module.icon;
 return <section className="sec-admin-module-page"><button className="sec-admin-back" onClick={onBack}><ChevronLeft size={16}/> Administration overview</button><div className="sec-admin-module-title"><span className="sec-admin-module-icon"><Icon size={22}/></span><div><div className="sec-admin-eyebrow"><span/> ADMINISTRATION MODULE</div><h1>{module.title}</h1><p>{module.description}</p></div></div><div className="sec-admin-status"><span className="sec-admin-status-dot"/> Feature scope defined <span>·</span> Database workflows will be connected in implementation stages</div><h2>Included features</h2><div className="sec-admin-feature-grid">{module.features.map((feature, index) => <div className="sec-admin-feature" key={feature}><span>{String(index + 1).padStart(2, "0")}</span><p>{feature}</p></div>)}</div><div className="sec-admin-implementation"><strong>Implementation status</strong><p>This page defines the administration features. Data entry, editing, approvals and reports will be enabled when this module's database tables, validation and role-specific RLS policies are implemented. No sample records are shown.</p></div></section>;
}
