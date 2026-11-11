// Compte une visite par page affichée (anonyme). Nécessite config.js.
(function(){try{
if(!window.SB_URL||!window.SB_KEY||/^(localhost|127\.)/.test(location.hostname)||navigator.webdriver)return;
var k='fv',v=null;try{v=localStorage.getItem(k);if(!v){v=Math.random().toString(36).slice(2)+Date.now().toString(36);localStorage.setItem(k,v)}}catch(e){}
var s='fp'+location.pathname;try{if(sessionStorage.getItem(s))return;sessionStorage.setItem(s,1)}catch(e){}
var r='';try{r=document.referrer?new URL(document.referrer).hostname:''}catch(e){}if(r==location.hostname)r='';
fetch(window.SB_URL+'/rest/v1/visites',{method:'POST',keepalive:true,headers:{apikey:window.SB_KEY,Authorization:'Bearer '+window.SB_KEY,'Content-Type':'application/json',Prefer:'return=minimal'},
body:JSON.stringify({page:(location.pathname.split('/').pop()||'index.html').slice(0,190),visiteur:v,provenance:r.slice(0,290)||null})}).catch(function(){})
}catch(e){}})();
// Application installable (hors connexion pour les pages déjà ouvertes)
if('serviceWorker' in navigator&&location.protocol=='https:'){addEventListener('load',function(){navigator.serviceWorker.register('sw.js').catch(function(){})})}
