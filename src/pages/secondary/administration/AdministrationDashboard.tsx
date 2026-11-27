import {useCallback,useEffect,useMemo,useState} from "react";
import {Activity,ArrowUpRight,CalendarDays,CheckCircle2,Clock,Coins,GraduationCap,RefreshCw,Users,Wallet,ClipboardCheck,Bell,UserCheck} from "lucide-react";
import {supabase} from "../../../lib/supabase";
import "./dashboard.css";

type Row=Record<string,any>;
type Props={schoolId:string;role:string;onOpen:(id:string)=>void};
const money=(n:number)=>new Intl.NumberFormat("en-MW",{style:"currency",currency:"MWK",maximumFractionDigits:0}).format(n);
const dateInMalawi=()=>new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Blantyre",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
const displayDate=(v:string)=>v?new Intl.DateTimeFormat("en-MW",{timeZone:"Africa/Blantyre",day:"numeric",month:"short"}).format(new Date(v+"T12:00:00")):"—";
const fullName=(s:Row)=>[s.first_name,s.middle_name,s.last_name].filter(Boolean).join(" ")||"Student";
function BarChart({title,caption,items,format=(v:number)=>v.toLocaleString()}: {title:string;caption?:string;items:{label:string;value:number}[];format?:(v:number)=>string}){
 const max=Math.max(1,...items.map(x=>x.value));
 return <section className="adm-dash-panel"><header><div><h3>{title}</h3>{caption&&<p>{caption}</p>}</div></header>{items.length?<div className="adm-dash-bars">{items.map((x,i)=><div className="adm-dash-bar-row" key={x.label}><span title={x.label}>{x.label}</span><div className="adm-dash-bar-track"><i style={{width:`${Math.max(x.value?3:0,x.value/max*100)}%`}}/></div><strong>{format(x.value)}</strong></div>)}</div>:<div className="adm-dash-empty">Not enough recorded data yet.</div>}</section>;
}
function Ring({value,label}: {value:number;label:string}){return <div className="adm-dash-ring" style={{background:`conic-gradient(#5b70e8 ${Math.max(0,Math.min(100,value))}%,#e9edf5 0)`}}><div><strong>{Math.round(value)}%</strong><span>{label}</span></div></div>}
export default function AdministrationDashboard({schoolId,role,onOpen}:Props){
 const [data,setData]=useState<Row>({}),[loading,setLoading]=useState(true),[error,setError]=useState("");
 const load=useCallback(async()=>{
  if(!supabase){setLoading(false);setError("Supabase is not configured.");return}
  setLoading(true);setError("");const today=dateInMalawi();
  const requests=[
   supabase.from("students").select("id,status,sex,created_at,first_name,middle_name,last_name,admission_number").eq("school_id",schoolId),
   supabase.from("student_enrollments").select("student_id,class_id,status,enrollment_date,exit_date,academic_year_id").eq("school_id",schoolId),
   supabase.from("classes").select("id,name,academic_year_id,is_active").eq("school_id",schoolId).eq("is_active",true),
   supabase.from("staff_profiles").select("id,membership_id,is_active,employment_title").eq("school_id",schoolId).eq("is_active",true),
   supabase.from("school_memberships").select("id,role,is_active,user_id").eq("school_id",schoolId).eq("is_active",true),
   supabase.from("attendance_sessions").select("id,class_id,attendance_date,status,taken_by_membership_id").eq("school_id",schoolId).eq("attendance_date",today),
   supabase.from("school_exams").select("id,name,start_date,end_date,status,academic_year_id").eq("school_id",schoolId).gte("end_date",today).order("start_date",{ascending:true}).limit(8),
   supabase.from("school_fee_accounts").select("id,student_id,fee_name,amount,discount_amount,due_date,created_at").eq("school_id",schoolId),
   supabase.from("school_fee_payments").select("id,account_id,amount,received_at,receipt_number").eq("school_id",schoolId).order("received_at",{ascending:false}).limit(8),
   supabase.from("school_announcements").select("id,title,status,priority,publish_at,created_at,audience").eq("school_id",schoolId).eq("status","published").order("publish_at",{ascending:false}).limit(6),
   supabase.from("school_access_audit").select("id,action,created_at").eq("school_id",schoolId).order("created_at",{ascending:false}).limit(8),
   supabase.from("school_exams").select("id,name,status,start_date").eq("school_id",schoolId).in("status",["submitted","pending_review","awaiting_approval"]).limit(10),
   supabase.from("school_discipline_cases").select("id,status,created_at").eq("school_id",schoolId).in("status",["pending_review","awaiting_approval"]).limit(10),
   supabase.from("primary_staff_attendance").select("id,status,attendance_date").eq("school_id",schoolId).eq("attendance_date",today),
   supabase.from("attendance_sessions").select("id,class_id,attendance_date,status").eq("school_id",schoolId).gte("attendance_date",new Date(Date.now()-30*86400000).toISOString().slice(0,10)).lte("attendance_date",today).in("status",["submitted","locked"]),
   supabase.from("school_exam_subjects").select("id,exam_id,class_id,maximum_mark,status").eq("school_id",schoolId),
   supabase.from("school_exam_marks").select("exam_subject_id,student_id,mark").eq("school_id",schoolId),
   supabase.from("school_exams").select("id,status,academic_year_id").eq("school_id",schoolId).in("status",["published","approved","completed"]),
   supabase.from("school_announcement_audit").select("id,action,changed_at").eq("school_id",schoolId).order("changed_at",{ascending:false}).limit(8),
   supabase.from("primary_staff_leave_requests").select("id,status,start_date").eq("school_id",schoolId).eq("status","pending").limit(10)
  ];
  const results=await Promise.all(requests);const pick=(i:number)=>results[i].error?[]:(results[i].data||[]) as Row[];
  const critical=[0,1,2,3,4,5,7,8].map(i=>results[i].error).filter(Boolean);
  if(critical.length){setError(critical[0].message);setLoading(false);return}
  const students=pick(0),enrollments=pick(1),classes=pick(2),staff=pick(3),members=pick(4),todaySessions=pick(5),exams=pick(6),accounts=pick(7),payments=pick(8),announcements=pick(9),accessAudit=pick(10),examApprovals=pick(11),caseApprovals=pick(12),teacherAttendance=pick(13),trendSessions=pick(14),examSubjects=pick(15),marks=pick(16),publishedExams=pick(17),announcementAudit=pick(18),leaveApprovals=pick(19);
  const sessionIds=todaySessions.map(x=>x.id);let todayRecords:Row[]=[];
  if(sessionIds.length){const r=await supabase.from("attendance_records").select("session_id,student_id,status").eq("school_id",schoolId).in("session_id",sessionIds);if(!r.error)todayRecords=(r.data||[]) as Row[]}
  let trendRecords:Row[]=[];if(trendSessions.length){const r=await supabase.from("attendance_records").select("session_id,status").eq("school_id",schoolId).in("session_id",trendSessions.map(x=>x.id));if(!r.error)trendRecords=(r.data||[]) as Row[]}
  const accountIds=accounts.map(x=>x.id);let allPayments:Row[]=payments;
  if(accountIds.length){const r=await supabase.from("school_fee_payments").select("account_id,amount,received_at").eq("school_id",schoolId).in("account_id",accountIds);if(!r.error)allPayments=r.data as Row[]}
  const paidByAccount=new Map<string,number>();for(const p of allPayments)paidByAccount.set(p.account_id,(paidByAccount.get(p.account_id)||0)+Number(p.amount||0));
  const totalDue=accounts.reduce((sum,a)=>sum+Math.max(0,Number(a.amount||0)-Number(a.discount_amount||0)),0),totalPaid=allPayments.reduce((sum,p)=>sum+Number(p.amount||0),0),outstanding=accounts.reduce((sum,a)=>sum+Math.max(0,Number(a.amount||0)-Number(a.discount_amount||0)-(paidByAccount.get(a.id)||0)),0);
  const todayTotal=todayRecords.length,todayPresent=todayRecords.filter(r=>["present","late"].includes(r.status)).length;
  const activeEnrollment=enrollments.filter(e=>e.status==="enrolled"),enrolledIds=new Set(activeEnrollment.map(e=>e.student_id));
  const waiting=students.filter(s=>["awaiting_admission","pending_admission","pending"].includes(String(s.status).toLowerCase())).length;
  const withdrawn=students.filter(s=>String(s.status).toLowerCase()==="withdrawn").length;
  const studentMap=new Map(students.map(s=>[s.id,s]));
  const paymentRows=payments.slice(0,5).map(p=>({...p,student:studentMap.get(accounts.find(a=>a.id===p.account_id)?.student_id)||null}));
  const classCounts=classes.map(c=>({label:c.name,value:activeEnrollment.filter(e=>e.class_id===c.id).length})).sort((a,b)=>b.value-a.value).slice(0,8);
  const months=Array.from({length:6},(_,i)=>{const d=new Date();d.setMonth(d.getMonth()-5+i);return {key:d.toISOString().slice(0,7),label:d.toLocaleDateString("en-MW",{month:"short"})}});
  const population=months.map(m=>({label:m.label,value:students.filter(s=>String(s.created_at||"").slice(0,7)<=m.key).length}));
  const sexCounts=[{label:"Female",value:students.filter(s=>["female","f"].includes(String(s.sex||"").toLowerCase())).length},{label:"Male",value:students.filter(s=>["male","m"].includes(String(s.sex||"").toLowerCase())).length},{label:"Not recorded",value:students.filter(s=>!s.sex).length}];
  const trend=months.map(m=>{const ss=trendSessions.filter(s=>String(s.attendance_date).slice(0,7)===m.key),ids=new Set(ss.map(s=>s.id)),rs=trendRecords.filter(r=>ids.has(r.session_id));return {label:m.label,value:rs.length?rs.filter(r=>["present","late"].includes(r.status)).length/rs.length*100:0}});
  const examClass=new Map(examSubjects.map(x=>[x.id,x]));const publishedIds=new Set(publishedExams.map(x=>x.id));
  const performance=classes.map(c=>{const subjects=examSubjects.filter(x=>x.class_id===c.id&&publishedIds.has(x.exam_id));const subIds=new Set(subjects.map(x=>x.id));const classMarks=marks.filter(m=>subIds.has(m.exam_subject_id)&&m.mark!==null);const max=subjects.reduce((n,s)=>n+Number(s.maximum_mark||0),0);const got=classMarks.reduce((n,m)=>n+Number(m.mark||0),0);return {label:c.name,value:max?got/max*100:0}}).filter(x=>x.value>0).sort((a,b)=>b.value-a.value).slice(0,8);
  const approvalCount=examApprovals.length+caseApprovals.length+leaveApprovals.length;
  const activity=[...accessAudit.map(x=>({id:x.id,action:x.action,date:x.created_at,type:"Access"})),...announcementAudit.map(x=>({id:x.id,action:x.action,date:x.changed_at,type:"Announcement"}))].sort((a,b)=>String(b.date).localeCompare(String(a.date))).slice(0,6);
  setData({students,staff,members,enrollments,classes,todaySessions,todayRecords,exams,accounts,payments,announcements,teacherAttendance,waiting,withdrawn,enrolled:enrolledIds.size,activeStaff:staff.length,teacherCount:members.filter(m=>m.role==="teacher").length,todayTotal,todayPresent,attendanceRate:todayTotal?todayPresent/todayTotal*100:0,teacherPresent:teacherAttendance.filter(x=>["present","late"].includes(x.status)).length,teacherMarked:teacherAttendance.length,totalDue,totalPaid,outstanding,collectionRate:totalDue?totalPaid/totalDue*100:0,paymentRows,classCounts,population,sexCounts,trend,performance,approvalCount,examApprovals,caseApprovals,leaveApprovals,activity});
  setLoading(false);
 },[schoolId]);
 useEffect(()=>{void load()},[load]);
 const d=data as Row;const finance=["owner","school_admin","headteacher","bursar"].includes(role);
 const stat=[{label:"Total students",value:d.students?.length||0,note:"All registered records",icon:GraduationCap,action:"students"},{label:"Teachers & staff",value:d.staff?.length||0,note:"Active staff profiles",icon:Users,action:"staff"},{label:"Currently enrolled",value:d.enrolled||0,note:"Active enrolments",icon:UserCheck,action:"students"},{label:"Awaiting admission",value:d.waiting||0,note:"Admission queue",icon:Clock,action:"students"},{label:"Withdrawn students",value:d.withdrawn||0,note:"Withdrawal records",icon:ArrowUpRight,action:"students"}];
 return <div className="adm-dashboard">
  <div className="adm-dash-welcome"><div><div className="adm-dash-eyebrow">SECONDARY SCHOOL · ADMINISTRATOR</div><h1>School overview</h1><p>Your school's live operational summary and daily priorities.</p></div><button onClick={()=>void load()} disabled={loading}><RefreshCw size={15} className={loading?"adm-dash-spin":""}/>{loading?"Refreshing":"Refresh data"}</button></div>
  {error&&<div className="adm-dash-error">Dashboard data could not fully load: {error}. Check your school access and database policies.</div>}
  <div className="adm-dash-stat-grid">{stat.map(s=>{const Icon=s.icon;return <button className="adm-dash-stat" key={s.label} onClick={()=>onOpen(s.action)}><span className="adm-dash-stat-icon"><Icon size={18}/></span><span className="adm-dash-stat-label">{s.label}</span><strong>{loading?"—":s.value.toLocaleString()}</strong><small>{s.note}</small><ArrowUpRight size={14} className="adm-dash-stat-arrow"/></button>})}</div>
  <div className="adm-dash-main-grid">
   <section className="adm-dash-panel adm-dash-attendance"><header><div><h3>Today's attendance</h3><p>Student attendance recorded for today</p></div><button onClick={()=>onOpen("attendance")}>Open register <ArrowUpRight size={14}/></button></header><div className="adm-dash-attendance-body"><Ring value={d.attendanceRate||0} label="Present / late"/><div className="adm-dash-attendance-numbers"><div><strong>{loading?"—":(d.todayPresent||0).toLocaleString()}</strong><span>Present or late</span></div><div><strong>{loading?"—":(d.todayTotal||0).toLocaleString()}</strong><span>Attendance marks</span></div><div><strong>{loading?"—":(d.todaySessions?.length||0).toLocaleString()}</strong><span>Class registers</span></div></div></div></section>
   <section className="adm-dash-panel"><header><div><h3>Teacher attendance</h3><p>Staff register for today</p></div><UserCheck size={18}/></header><div className="adm-dash-teacher-stat"><strong>{loading?"—":(d.teacherPresent||0)}</strong><span>Present / late</span><small>{loading?"—":(d.teacherMarked||0)} staff attendance records</small></div><button className="adm-dash-panel-link" onClick={()=>onOpen("staff")}>Manage staff <ArrowUpRight size={14}/></button></section>
   <section className="adm-dash-panel"><header><div><h3>Fee collection</h3><p>Recorded fee accounts and payments</p></div><Wallet size={18}/></header>{finance?<><div className="adm-dash-finance-figures"><div><span>Collected</span><strong>{loading?"—":money(d.totalPaid||0)}</strong></div><div><span>Outstanding</span><strong>{loading?"—":money(d.outstanding||0)}</strong></div></div><div className="adm-dash-progress"><i style={{width:`${Math.min(100,d.collectionRate||0)}%`}}/></div><small className="adm-dash-muted">{loading?"—":Math.round(d.collectionRate||0)}% of billed fees collected</small><button className="adm-dash-panel-link" onClick={()=>onOpen("fees")}>View finance <ArrowUpRight size={14}/></button></>:<div className="adm-dash-restricted">Finance summary is restricted to authorised roles.</div>}</section>
   <section className="adm-dash-panel"><header><div><h3>Upcoming examinations</h3><p>Scheduled exams from the school calendar</p></div><CalendarDays size={18}/></header><div className="adm-dash-list">{(d.exams||[]).slice(0,4).map((x:Row)=><div className="adm-dash-list-row" key={x.id}><span className="adm-dash-date-chip">{displayDate(x.start_date)}</span><div><strong>{x.name}</strong><small>{x.status||"Scheduled"}</small></div></div>)}{!loading&&!(d.exams||[]).length&&<div className="adm-dash-empty">No upcoming examinations scheduled.</div>}</div><button className="adm-dash-panel-link" onClick={()=>onOpen("exams")}>Exam management <ArrowUpRight size={14}/></button></section>
  </div>
  <div className="adm-dash-chart-grid">
   <BarChart title="Student enrolment by class" caption="Currently enrolled learners" items={d.classCounts||[]}/>
   <BarChart title="Attendance trends" caption="Present or late, last 6 months" items={d.trend||[]} format={v=>`${Math.round(v)}%`}/>
   {finance&&<BarChart title="Fee collection progress" caption="Collected vs outstanding (MWK)" items={[{label:"Collected",value:d.totalPaid||0},{label:"Outstanding",value:d.outstanding||0}]} format={v=>money(v)}/>}
   <BarChart title="Academic performance by class" caption="Published exam marks, weighted by maximum marks" items={d.performance||[]} format={v=>`${Math.round(v)}%`}/>
   <BarChart title="Gender distribution" caption="Student records by recorded sex" items={d.sexCounts||[]}/>
   <BarChart title="Student population over time" caption="Cumulative student registrations, last 6 months" items={d.population||[]}/>
  </div>
  <div className="adm-dash-lower-grid">
   <section className="adm-dash-panel"><header><div><h3>Recent payments</h3><p>Latest recorded fee receipts</p></div><Coins size={18}/></header>{finance?<div className="adm-dash-list">{(d.paymentRows||[]).map((p:Row)=><div className="adm-dash-list-row" key={p.id}><span className="adm-dash-payment-icon"><Coins size={15}/></span><div><strong>{p.student?fullName(p.student):"Student fee payment"}</strong><small>{p.receipt_number||"Payment"} · {p.received_at?new Date(p.received_at).toLocaleDateString("en-MW"):""}</small></div><b>{money(Number(p.amount||0))}</b></div>)}{!loading&&!(d.paymentRows||[]).length&&<div className="adm-dash-empty">No payments recorded yet.</div>}</div>:<div className="adm-dash-restricted">Payment details are restricted to authorised roles.</div>}<button className="adm-dash-panel-link" onClick={()=>onOpen("fees")}>View payments <ArrowUpRight size={14}/></button></section>
   <section className="adm-dash-panel"><header><div><h3>Pending approvals</h3><p>Items requiring administrator review</p></div><ClipboardCheck size={18}/></header><div className="adm-dash-approval-count">{loading?"—":(d.approvalCount||0)}<span>pending items</span></div><div className="adm-dash-approval-links"><button onClick={()=>onOpen("exams")}>Exam approvals <b>{d.examApprovals?.length||0}</b></button><button onClick={()=>onOpen("discipline")}>Welfare review <b>{d.caseApprovals?.length||0}</b></button><button onClick={()=>onOpen("staff")}>Leave requests <b>{d.leaveApprovals?.length||0}</b></button></div></section>
   <section className="adm-dash-panel"><header><div><h3>Recent notifications</h3><p>Published school announcements</p></div><Bell size={18}/></header><div className="adm-dash-list">{(d.announcements||[]).slice(0,5).map((n:Row)=><div className="adm-dash-list-row" key={n.id}><span className="adm-dash-notice-dot"/><div><strong>{n.title}</strong><small>{n.priority||"Notice"} · {n.publish_at?new Date(n.publish_at).toLocaleDateString("en-MW"):"Published"}</small></div></div>)}{!loading&&!(d.announcements||[]).length&&<div className="adm-dash-empty">No published announcements yet.</div>}</div><button className="adm-dash-panel-link" onClick={()=>onOpen("communications")}>Open announcements <ArrowUpRight size={14}/></button></section>
   <section className="adm-dash-panel"><header><div><h3>Upcoming school events</h3><p>School calendar and activities</p></div><CalendarDays size={18}/></header><div className="adm-dash-event-empty"><CalendarDays size={22}/><strong>Events calendar not connected</strong><span>Add a dedicated school-events calendar to display sports, meetings and school functions here.</span></div><button className="adm-dash-panel-link" onClick={()=>onOpen("academic-calendar")}>Open academic calendar <ArrowUpRight size={14}/></button></section>
  </div>
  <section className="adm-dash-panel adm-dash-activity"><header><div><h3>Recent system activity</h3><p>Administrative access and announcement changes</p></div><Activity size={18}/></header><div className="adm-dash-activity-list">{(d.activity||[]).map((a:Row)=><div key={a.id}><span>{a.type}</span><strong>{String(a.action||"Activity").replaceAll("_"," ")}</strong><small>{a.date?new Date(a.date).toLocaleString("en-MW"):""}</small></div>)}{!loading&&!(d.activity||[]).length&&<div className="adm-dash-empty">No system activity has been recorded yet.</div>}</div></section>
  <div className="adm-dash-quick"><div><h3>Quick actions</h3><p>Jump directly to common administration tasks.</p></div><div>{[{id:"students",label:"Register student",icon:GraduationCap},{id:"staff",label:"Add staff",icon:Users},{id:"attendance",label:"Take attendance",icon:CheckCircle2},{id:"exams",label:"Create examination",icon:ClipboardCheck},{id:"fees",label:"Record payment",icon:Wallet},{id:"communications",label:"Publish notice",icon:Bell}].map(a=>{const Icon=a.icon;return <button key={a.id} onClick={()=>onOpen(a.id)}><Icon size={17}/>{a.label}<ArrowUpRight size={14}/></button>})}</div></div>
 </div>;
}
