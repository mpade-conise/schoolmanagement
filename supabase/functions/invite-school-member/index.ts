import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const reply=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const inviteRoles=["headteacher","deputy_headteacher","bursar","teacher","class_teacher","academic_officer","parent","student","proprietor"];
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 const auth=req.headers.get("Authorization");
 if(!auth?.startsWith("Bearer "))return reply(401,{error:"Sign in required"});
 const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return reply(500,{error:"Invitation service is not configured"});
 const callerClient=createClient(url,anon,{global:{headers:{Authorization:auth}}});
 const {data:{user},error:userError}=await callerClient.auth.getUser();
 if(userError||!user)return reply(401,{error:"Invalid session"});
 let body:{email?:string;full_name?:string;school_id?:string;role?:string};
 try{body=await req.json()}catch{return reply(400,{error:"Invalid request body"})}
 const email=body.email?.trim().toLowerCase(),fullName=body.full_name?.trim(),schoolId=body.school_id,role=body.role;
 if(!email||!fullName||!schoolId||!role||fullName.length<2||fullName.length>160||!/^\S+@\S+\.\S+$/.test(email))return reply(400,{error:"Valid email, full name, school and role are required"});
 if(!inviteRoles.includes(role))return reply(400,{error:"That role cannot be assigned through staff invitations"});
 const admin=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}});
 const {data:membership,error:membershipError}=await admin.from("school_memberships").select("id").eq("school_id",schoolId).eq("user_id",user.id).eq("role","school_admin").eq("is_active",true).maybeSingle();
 if(membershipError)return reply(500,{error:"Could not verify school administrator permission"});
 if(!membership)return reply(403,{error:"Only the designated school administrator can invite members"});
 const {data:school,error:schoolError}=await admin.from("schools").select("id,name,school_type").eq("id",schoolId).maybeSingle();
 if(schoolError||!school)return reply(404,{error:"School not found"});
 const {data:invited,error:inviteError}=await admin.auth.admin.inviteUserByEmail(email,{data:{full_name:fullName},redirectTo:new URL("/",req.headers.get("origin")||url).toString()});
 if(inviteError||!invited.user)return reply(400,{error:inviteError?.message||"Invitation could not be sent"});
 const {error:insertError}=await admin.from("school_memberships").insert({school_id:schoolId,user_id:invited.user.id,role,is_active:true});
 if(insertError){await admin.auth.admin.deleteUser(invited.user.id);return reply(400,{error:"Invitation could not be assigned to this school and role"});}
 return reply(200,{success:true,message:"Invitation sent. The account will receive only the role assigned by this school.",school:school.name,role});
});