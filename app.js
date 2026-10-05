if(window.SB_URL)window.SB_URL=window.SB_URL.trim().replace(/\/(rest|auth)\/v1.*$/,'').replace(/\/+$/,'');
if(window.SB_KEY)window.SB_KEY=window.SB_KEY.trim();
var $=function(i){return document.getElementById(i)};
function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
function sv(k,v){try{if(v==null)localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){}}
function ld(k){try{return localStorage.getItem(k)}catch(e){return null}}
var A={tok:ld('t'),ref:ld('r'),
uid:function(){try{return JSON.parse(atob(this.tok.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).sub}catch(e){return null}},
set:function(j){this.tok=j.access_token;this.ref=j.refresh_token;sv('t',this.tok);sv('r',this.ref)},
out:function(){this.tok=this.ref=null;sv('t');sv('r')},
auth:async function(p,b){var r=await fetch(SB_URL+'/auth/v1/'+p,{method:'POST',headers:{apikey:SB_KEY,'Content-Type':'application/json'},body:JSON.stringify(b)}),j=await r.json();if(!r.ok)throw new Error(j.msg||j.error_description||j.message||r.status);return j},
login:async function(e,p){this.set(await this.auth('token?grant_type=password',{email:e,password:p}))},
signup:async function(e,p,n,pr){var j=await this.auth('signup',{email:e,password:p,data:{nom:n,prenom:pr}});if(j.access_token)this.set(j);else throw new Error('confirm')},
q:async function(path,m,body,pref){for(var i=0;i<2;i++){
var r=await fetch(SB_URL+'/rest/v1/'+path,{method:m||'GET',headers:{apikey:SB_KEY,Authorization:'Bearer '+this.tok,'Content-Type':'application/json',Prefer:pref||'return=representation'},body:body?JSON.stringify(body):undefined});
if(r.status==401&&this.ref&&!i){try{this.set(await this.auth('token?grant_type=refresh_token',{refresh_token:this.ref}));continue}catch(e){this.out();throw new Error('Session expirée')}}
var t=await r.text();if(!r.ok)throw new Error(t);return t?JSON.parse(t):null}}};
