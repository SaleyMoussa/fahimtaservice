// Affiche les vidéos YouTube liées à la page (géré dans l'Espace formateur > Vidéos YouTube).
// Usage : <div id="VID" data-page="cours-word.html"></div> ou data-general="1" pour l'accueil.
(function(){var B=document.getElementById('VID');if(!B||!window.SB_URL)return;
function yid(u){var m=String(u).match(/(?:youtu\.be\/|v=|embed\/|shorts\/|live\/)([\w-]{11})/);return m?m[1]:null}
function e(s){return String(s==null?'':s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
var H={apikey:SB_KEY,Authorization:'Bearer '+SB_KEY},pg=B.dataset.page,q=pg?'videos?select=titre,url,ordre,courses!inner(page)&courses.page=eq.'+encodeURIComponent(pg)+'&order=ordre,id':'videos?select=titre,url,ordre,courses(titre)&order=ordre,id&limit=12';
Promise.all([fetch(SB_URL+'/rest/v1/'+q,{headers:H}).then(function(r){return r.ok?r.json():[]}),fetch(SB_URL+'/rest/v1/reglages?cle=eq.youtube&select=valeur',{headers:H}).then(function(r){return r.ok?r.json():[]})]).then(function(r){
var V=r[0]||[],ch=((r[1]||[])[0]||{}).valeur||'';if(!V.length&&!ch)return;
var h='<h2 class="vh">'+(pg?'Vidéos du cours':'Nos vidéos sur YouTube')+'</h2>'+(pg?'<p class="vs">Des vidéos pour revoir les gestes du cours.</p>':'<p class="vs">Tutoriels gratuits pour apprendre à votre rythme.</p>')+'<div class="vg">'+V.map(function(v){var i=yid(v.url);
return '<a class="vc" href="'+e(v.url)+'" target="_blank" rel="noopener"><span class="vt">'+(i?'<img loading="lazy" alt="" onerror="this.remove()" src="https://i.ytimg.com/vi/'+i+'/mqdefault.jpg">':'')+'<span class="vp" aria-hidden="true">▶</span></span><b>'+e(v.titre)+'</b>'+(!pg&&v.courses?'<small>'+e(v.courses.titre)+'</small>':'')+'</a>'}).join('')+'</div>'+(ch?'<p><a class="vb" href="'+e(ch)+'" target="_blank" rel="noopener">▶ Voir toutes nos vidéos sur YouTube</a></p>':'');
B.innerHTML=h;B.hidden=false}).catch(function(){})})();
