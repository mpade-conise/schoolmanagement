import {useState} from "react";
import {ClipboardCheck,FileText} from "lucide-react";
import ExaminationsResults from "../../secondary/administration/ExaminationsResults";
import PrimaryReportCards from "./PrimaryReportCards";
export default function PrimaryAssessments({schoolId,schoolName,canManage,canReview,canEnterMarks,onBack}:{schoolId:string;schoolName:string;canManage:boolean;canReview:boolean;canEnterMarks:boolean;onBack:()=>void}){
 const [view,setView]=useState<"assessments"|"reports">("assessments");
 return <section className="sec-primary-assessments"><div className="sec-primary-assessment-tabs"><button className={view==="assessments"?"active":""} onClick={()=>setView("assessments")}><ClipboardCheck size={15}/> Assessments & marks</button><button className={view==="reports"?"active":""} onClick={()=>setView("reports")}><FileText size={15}/> Term report cards</button></div>{view==="assessments"?<ExaminationsResults schoolId={schoolId} educationLevel="primary" canManage={canManage} canReview={canReview} canEnterMarks={canEnterMarks} onBack={onBack}/>:<PrimaryReportCards schoolId={schoolId} schoolName={schoolName} onBack={onBack}/>}</section>;
}
