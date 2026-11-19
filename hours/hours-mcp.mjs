#!/usr/bin/env node
// Pavoot Hours MCP server (stdio, zero dependencies, Node 18+).
// Env: HOURS_KEY = your personal key (from the app: Settings -> Copy my sign-in link, the part after #k=)
const API_R='https://ep-sweet-heart-b9jc9c7i.apirest.c-7.eu-central-1.aws.neon.tech/neondb/rest/v1';
const API_A='https://ep-sweet-heart-b9jc9c7i.neonauth.c-7.eu-central-1.aws.neon.tech/neondb/auth/token/anonymous';
const KEY=(process.env.HOURS_KEY||'').trim();
let TOK=null,TOKT=0;
async function token(force){if(!force&&TOK&&Date.now()-TOKT<240000)return TOK;const r=await fetch(API_A);if(!r.ok)throw new Error('auth server '+r.status);TOK=(await r.json()).token;TOKT=Date.now();return TOK}
async function rpc(fn,args){if(!KEY)throw new Error('HOURS_KEY is not set');for(let i=0;i<2;i++){const t=await token(i>0);const r=await fetch(API_R+'/rpc/'+fn,{method:'POST',headers:{Authorization:'Bearer '+t,'Content-Type':'application/json'},body:JSON.stringify({p_key:KEY,...(args||{})})});const d=await r.json().catch(()=>null);if(r.ok)return norm(d);if(i===0&&r.status===401&&!(d&&d.code==='28000'))continue;throw new Error((d&&d.message)||('HTTP '+r.status))}}
function norm(d){return {...d,entries:(d.entries||[]).map(x=>({...x,s:+new Date(x.s),e:x.e?+new Date(x.e):null}))}}
const DAY=864e5;
function sod(t){const d=new Date(t);d.setHours(0,0,0,0);return +d}
function addDays(t,n){const d=new Date(t);d.setDate(d.getDate()+n);return +d}
function sow(t){const d=new Date(sod(t));d.setDate(d.getDate()-(d.getDay()+6)%7);return +d}
function ymd(t){const d=new Date(t);return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
function pymd(s){const p=s.split('-').map(Number);return +new Date(p[0],p[1]-1,p[2])}
function fmtH(h){const m=Math.round(h*60);return Math.floor(m/60)+'h '+String(m%60).padStart(2,'0')+'m'}
function hrs(S,u,a,b){const n=Date.now();let s=0;for(const x of S.entries){if(x.u!==u)continue;const v=Math.min(x.e||n,b)-Math.max(x.s,a);if(v>0)s+=v}return s/36e5}
function offs(S,u,a,b){return S.off.filter(o=>o.u===u&&pymd(o.d)>=a&&pymd(o.d)<b)}
function goal(S){return Number(S.settings.goal_hours)||70}
function wd(S){return Number(S.settings.work_days)||7}
function target(S,u,a,b){const days=Math.round((b-a)/DAY);return Math.max(0,goal(S)*days/7-Math.min(days,offs(S,u,a,b).length)*goal(S)/wd(S))}
function range(period,offset){const n=new Date(),o=Number(offset)||0;if(period==='today'){const a=addDays(sod(n),o);return [a,addDays(a,1),ymd(a)]}if(period==='month'){const a=+new Date(n.getFullYear(),n.getMonth()+o,1);return [a,+new Date(n.getFullYear(),n.getMonth()+o+1,1),new Date(a).toLocaleDateString('en-GB',{month:'long',year:'numeric'})]}if(period==='year'){const a=+new Date(n.getFullYear()+o,0,1);return [a,+new Date(n.getFullYear()+o+1,0,1),String(n.getFullYear()+o)]}const a=addDays(sow(n),7*o);return [a,addDays(a,7),'week of '+ymd(a)]}
function name(S,u){return (S.users.find(x=>x.id===u)||{name:u}).name}
function findUser(S,q){if(!q||q==='me')return S.me;q=String(q).toLowerCase();const u=S.users.find(x=>x.id===q||x.name.toLowerCase()===q||x.name.toLowerCase().startsWith(q));if(!u)throw new Error('Unknown person: '+q+'. Known: '+S.users.map(x=>x.name).join(', '));return u.id}
function status(S){const n=Date.now(),ws=sow(n),we=addDays(ws,7),L=['Goal: '+goal(S)+'h per week each ('+wd(S)+' work days).'];for(const u of S.users){const r=S.entries.find(x=>x.u===u.id&&!x.e),w=hrs(S,u.id,ws,we),tg=target(S,u.id,ws,we);L.push(`${u.name}${u.id===S.me?' (you)':''}: ${r?`TRACKING now for ${fmtH((n-r.s)/36e5)}${r.n?' on "'+r.n+'"':''}`:'not tracking'}. Today ${fmtH(hrs(S,u.id,sod(n),addDays(sod(n),1)))}, this week ${fmtH(w)} of ${fmtH(tg)} (${tg?Math.round(w/tg*100):100}%).`)}return L.join('\n')}
function summary(S,period,offset){const [a,b,lab]=range(period||'week',offset),L=['Summary for '+lab+':'];for(const u of S.users){const t=hrs(S,u.id,a,b),tg=target(S,u.id,a,b),days=[];for(let d=a;d<b;d=addDays(d,1)){const v=hrs(S,u.id,d,addDays(d,1));if(v>0)days.push(ymd(d)+' '+fmtH(v))}const o=offs(S,u.id,a,b);L.push(`\n${u.name}: ${fmtH(t)} of ${fmtH(tg)} goal (${tg?Math.round(t/tg*100):100}%), ${days.length} days worked, ${o.length} days off.`);if(days.length&&(b-a)<=32*DAY)L.push('  Per day: '+days.join(', '));if(o.length)L.push('  Days off: '+o.map(x=>x.d+' '+x.k+(x.r?' ('+x.r+')':'')).join(', '))}return L.join('\n')}
function parseTime(v,base){if(!v)return null;if(/^\d{1,2}:\d{2}$/.test(v)){const d=new Date(base||Date.now());const [h,m]=v.split(':').map(Number);d.setHours(h,m,0,0);return +d}const t=Date.parse(v);if(isNaN(t))throw new Error('Could not read time: '+v+' (use ISO like 2026-11-19T09:00 or HH:MM)');return t}
const TOOLS=[
{name:'start_timer',description:'Start the timer now for the signed-in person (stops any running one first).',inputSchema:{type:'object',properties:{note:{type:'string',description:'What you are working on'}}}},
{name:'stop_timer',description:'Stop the running timer.',inputSchema:{type:'object',properties:{}}},
{name:'status',description:'Who is tracking right now, plus today and this week vs the weekly goal for every founder.',inputSchema:{type:'object',properties:{}}},
{name:'summary',description:'Hours, goal progress, days worked and days off per founder for a week, month, year or a day.',inputSchema:{type:'object',properties:{period:{type:'string',enum:['today','week','month','year']},offset:{type:'integer',description:'0 = current, -1 = previous, ...'}}}},
{name:'list_entries',description:'List time entries (newest first).',inputSchema:{type:'object',properties:{person:{type:'string',description:'me, all, or a name like Gohar'},days:{type:'integer',description:'How many days back (default 7)'}}}},
{name:'log_time',description:'Add a finished time entry manually. start/end as ISO datetime or HH:MM (today).',inputSchema:{type:'object',properties:{start:{type:'string'},end:{type:'string'},note:{type:'string'},date:{type:'string',description:'YYYY-MM-DD when start/end are HH:MM'}},required:['start','end']}},
{name:'delete_entry',description:'Delete one of your own entries by id (from list_entries).',inputSchema:{type:'object',properties:{id:{type:'string'}},required:['id']}},
{name:'add_days_off',description:'Log one or more days off (inclusive range) with a reason.',inputSchema:{type:'object',properties:{from:{type:'string',description:'YYYY-MM-DD'},to:{type:'string',description:'YYYY-MM-DD, default = from'},kind:{type:'string',enum:['off','vacation','sick','holiday','other']},reason:{type:'string'}},required:['from']}},
{name:'remove_day_off',description:'Remove one of your logged days off by date.',inputSchema:{type:'object',properties:{date:{type:'string',description:'YYYY-MM-DD'}},required:['date']}},
{name:'set_goal',description:'Change the shared weekly goal (hours per week each) and/or work days per week.',inputSchema:{type:'object',properties:{hours_per_week:{type:'number'},work_days:{type:'integer'}}}}];
async function call(n,a){a=a||{};let S;switch(n){
case 'start_timer':S=await rpc('hr_start',{p_note:a.note||''});return 'Timer started'+(a.note?' for "'+a.note+'"':'')+'.\n\n'+status(S);
case 'stop_timer':{const b=await rpc('hr_state');const r=b.entries.find(x=>x.u===b.me&&!x.e);if(!r)return 'No timer was running.\n\n'+status(b);S=await rpc('hr_stop');return 'Stopped after '+fmtH((Date.now()-r.s)/36e5)+(r.n?' ("'+r.n+'")':'')+'.\n\n'+status(S)}
case 'status':return status(await rpc('hr_state'));
case 'summary':return summary(await rpc('hr_state'),a.period,a.offset);
case 'list_entries':{S=await rpc('hr_state');const days=Number(a.days)||7,from=addDays(sod(Date.now()),-days+1),who=a.person==='all'?null:findUser(S,a.person);const L=S.entries.filter(x=>x.s>=from&&(!who||x.u===who)).sort((p,q)=>q.s-p.s).map(x=>`${x.id} | ${name(S,x.u)} | ${new Date(x.s).toLocaleString('en-GB')} - ${x.e?new Date(x.e).toLocaleTimeString('en-GB'):'running'} | ${fmtH(((x.e||Date.now())-x.s)/36e5)} | ${x.n||'-'}`);return L.length?L.join('\n'):'No entries in that range.'}
case 'log_time':{const base=a.date?pymd(a.date):Date.now();const s=parseTime(a.start,base);let e=parseTime(a.end,base);if(e<=s&&/^\d/.test(a.end)&&a.end.length<=5)e=addDays(e,1);S=await rpc('hr_save_entry',{p_id:null,p_start:new Date(s).toISOString(),p_end:new Date(e).toISOString(),p_note:a.note||''});return 'Logged '+fmtH((e-s)/36e5)+'.\n\n'+status(S)}
case 'delete_entry':S=await rpc('hr_delete_entry',{p_id:a.id});return 'Deleted (if it was yours).\n\n'+status(S);
case 'add_days_off':S=await rpc('hr_add_off',{p_from:a.from,p_to:a.to||a.from,p_kind:a.kind||'off',p_reason:a.reason||''});return 'Days off saved.\n\n'+summary(S,'month',0);
case 'remove_day_off':{const b=await rpc('hr_state');const o=b.off.find(x=>x.u===b.me&&x.d===a.date);if(!o)return 'No day off logged for you on '+a.date;await rpc('hr_delete_off',{p_id:o.id});return 'Removed the day off on '+a.date+'.'}
case 'set_goal':S=await rpc('hr_set_settings',{p_goal:a.hours_per_week??null,p_days:a.work_days??null});return status(S);
default:throw new Error('Unknown tool '+n)}}
function send(m){process.stdout.write(JSON.stringify(m)+'\n')}
async function handle(m){const {id,method,params}=m;if(id===undefined||id===null)return;try{if(method==='initialize')return send({jsonrpc:'2.0',id,result:{protocolVersion:(params&&params.protocolVersion)||'2024-11-05',capabilities:{tools:{}},serverInfo:{name:'pavoot-hours',version:'1.0.0'}}});if(method==='ping')return send({jsonrpc:'2.0',id,result:{}});if(method==='tools/list')return send({jsonrpc:'2.0',id,result:{tools:TOOLS}});if(method==='tools/call'){try{const t=await call(params.name,params.arguments);return send({jsonrpc:'2.0',id,result:{content:[{type:'text',text:t}]}})}catch(e){return send({jsonrpc:'2.0',id,result:{content:[{type:'text',text:'Error: '+(e.message||e)}],isError:true}})}}send({jsonrpc:'2.0',id,error:{code:-32601,message:'Method not found: '+method}})}catch(e){send({jsonrpc:'2.0',id,error:{code:-32603,message:String(e.message||e)}})}}
let buf='';process.stdin.setEncoding('utf8');process.stdin.on('data',c=>{buf+=c;let i;while((i=buf.indexOf('\n'))>=0){const line=buf.slice(0,i).trim();buf=buf.slice(i+1);if(!line)continue;let m;try{m=JSON.parse(line)}catch(e){continue}handle(m)}});
