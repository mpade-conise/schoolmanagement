import { useEffect, useState } from "react";
import coneduLogo from "../assets/conedu-logo.svg";
import type { FormEvent, ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { LoaderCircle, LockKeyhole } from "lucide-react";
import { supabase } from "../lib/supabase";
type Props={children:ReactNode};
type Mode="signin"|"reset"|"update";
export default function AuthGate({children}:Props){
 const [session,setSession]=useState<Session|null>(null),[loading,setLoading]=useState(Boolean(supabase)),[mode,setMode]=useState<Mode>("signin"),[email,setEmail]=useState(""),[password,setPassword]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("");
 useEffect(()=>{if(!supabase)return;supabase.auth.getSession().then(({data})=>{setSession(data.session);setLoading(false)});const {data:{subscription}}=supabase.auth.onAuthStateChange((event,next)=>{setSession(next);if(event==="PASSWORD_RECOVERY")setMode("update")});return()=>subscription.unsubscribe()},[]);
 if(!supabase)return <main className="auth-screen"><section className="auth-card"><div className="auth-brand"><img src={coneduLogo} alt="ConEdu School Management"/></div><div className="auth-lock"><LockKeyhole size={20}/></div><h1>ConEdu setup required</h1><p>Secure school data is unavailable until the Supabase URL and publishable key are configured.</p><small>No demo or sample school data is loaded.</small></section></main>;
 if(loading)return <div className="auth-screen"><LoaderCircle className="spin" size={26}/><span>Checking secure session…</span></div>;
 if(session&&mode!=="update")return <>{children}</>;
 async function submit(e:FormEvent){e.preventDefault();if(!supabase)return;setBusy(true);setError("");setNotice("");try{
  if(mode==="signin"){const {error}=await supabase.auth.signInWithPassword({email:email.trim(),password});if(error)throw error}
  else if(mode==="reset"){const {error}=await supabase.auth.resetPasswordForEmail(email.trim(),{redirectTo:window.location.origin});if(error)throw error;setNotice("If an account exists for this email, a password reset link has been sent.")}
  else {const {error}=await supabase.auth.updateUser({password});if(error)throw error;await supabase.auth.signOut();setSession(null);setMode("signin");setPassword("");setNotice("Password updated. Sign in with your new password.")}
 }catch(err){setError(err instanceof Error?err.message:"Authentication failed.")}finally{setBusy(false)}}
 const title=mode==="reset"?"Reset your password":mode==="update"?"Choose a new password":"Sign in to ConEdu";
 const description=mode==="reset"?"Enter your account email to receive a secure reset link.":mode==="update"?"Set a new password for your account.":"Access is invitation-only. Your school administrator must create or invite your account and assign your role.";
 return <main className="auth-screen"><form className="auth-card" onSubmit={submit}><div className="auth-brand"><img src={coneduLogo} alt="ConEdu School Management"/></div><div className="auth-lock"><LockKeyhole size={20}/></div><h1>{title}</h1><p>{description}</p>{error&&<div className="auth-error" role="alert">{error}</div>}{notice&&<div className="setup-banner" role="status"><p>{notice}</p></div>}{mode!=="update"&&<label>Email address<input type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="name@example.com"/></label>}{mode!=="reset"&&<label>{mode==="update"?"New password":"Password"}<input type="password" autoComplete={mode==="update"?"new-password":"current-password"} required minLength={8} value={password} onChange={e=>setPassword(e.target.value)} placeholder="At least 8 characters"/></label>}<button className="auth-submit" disabled={busy}>{busy?<><LoaderCircle className="spin" size={16}/> Processing…</>:mode==="reset"?"Send reset link":mode==="update"?"Update password":"Sign in securely"}</button>{mode==="signin"&&<button type="button" className="text-button" onClick={()=>{setMode("reset");setError("");setNotice("")}}>Forgot password?</button>}{mode==="reset"&&<button type="button" className="text-button" onClick={()=>{setMode("signin");setError("");setNotice("")}}>Back to sign in</button>}{mode==="update"&&<small>Password reset is handled securely by Supabase.</small>}</form></main>
}