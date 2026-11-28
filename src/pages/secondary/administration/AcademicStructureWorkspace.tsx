import { useState } from "react";
import { BookOpen, Settings2 } from "lucide-react";
import ClassesSubjects from "./ClassesSubjects";
import AcademicStructureSettings from "./AcademicStructureSettings";

export default function AcademicStructureWorkspace({schoolId,canEdit,onBack}:{schoolId:string;canEdit:boolean;onBack:()=>void}){
 const [view,setView]=useState<"classes"|"settings">("classes");
 return <div className="sec-academic-workspace"><div className="sec-academic-workspace-tabs"><button className={view==="classes"?"active":""} onClick={()=>setView("classes")}><BookOpen size={16}/> Forms, streams & subjects</button><button className={view==="settings"?"active":""} onClick={()=>setView("settings")}><Settings2 size={16}/> Departments & academic rules</button></div>{view==="classes"?<ClassesSubjects schoolId={schoolId} canEdit={canEdit} onBack={onBack} educationLevel="secondary"/>:<AcademicStructureSettings schoolId={schoolId} canEdit={canEdit} onBack={onBack}/>}</div>;
}
