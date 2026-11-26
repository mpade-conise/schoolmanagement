export type SchoolType = "primary" | "secondary";
export type SchoolRole = "school_admin" | "headteacher" | "deputy_headteacher" | "bursar" | "teacher" | "class_teacher" | "academic_officer" | "parent" | "student" | "proprietor";
export type SchoolModule = "dashboard" | "students" | "staff" | "classes" | "attendance" | "fees" | "reports" | "settings" | "examinations" | "timetable" | "communications";
export const roleLabels: Record<SchoolRole, string> = {
  school_admin: "School Administrator",
  headteacher: "Headteacher / Principal",
  deputy_headteacher: "Deputy Headteacher",
  bursar: "Bursar / Accountant",
  teacher: "Teacher",
  class_teacher: "Class Teacher",
  academic_officer: "Registrar / Academic Officer",
  parent: "Parent / Guardian",
  student: "Student",
  proprietor: "Proprietor (optional)"
};
export const roleModules: Record<SchoolRole, readonly SchoolModule[]> = {
  school_admin: ["dashboard","students","staff","classes","attendance","fees","reports","settings","examinations","timetable","communications"],
  headteacher: ["dashboard","students","staff","classes","attendance","reports","examinations","timetable","communications"],
  deputy_headteacher: ["dashboard","students","classes","attendance","reports","examinations","timetable","communications"],
  bursar: ["dashboard","students","fees","reports"],
  teacher: ["dashboard","classes","attendance","examinations","timetable","communications"],
  class_teacher: ["dashboard","students","classes","attendance","examinations","reports","timetable","communications"],
  academic_officer: ["dashboard","students","classes","examinations","reports","timetable"],
  parent: ["dashboard","attendance","fees","reports","communications"],
  student: ["dashboard","classes","attendance","examinations","timetable","communications"],
  proprietor: ["dashboard","reports","fees"]
};
export const roleOptions = (_schoolType: SchoolType) => Object.entries(roleLabels).map(([value,label]) => ({ value: value as SchoolRole, label }));
export const canAccessModule = (role: SchoolRole, module: SchoolModule) => roleModules[role].includes(module);
