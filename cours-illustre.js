// Cours illustrés (schémas, leçons, quiz) : affichage dans une zone isolée (Shadow DOM)
// pour ne pas mélanger leurs styles avec ceux de la page.
// Usage : FI_render(document.getElementById('IL'), html, 'word')
(function(){
var CSS=':host{display:block;margin:28px 0;--muted:var(--mute,#56627a);--c2:color-mix(in srgb,var(--c) 12%,var(--card,#fff));--okc:var(--ok,#1d7a46);--koc:var(--ko,#b3261e);color:var(--ink);font:400 17px/1.65 Figtree,system-ui,sans-serif}'+
'*{box-sizing:border-box}a{color:var(--c)}h2,h3,h4{font-family:"Bricolage Grotesque",Figtree,sans-serif;line-height:1.2}'+
'.head{background:var(--c);color:#fff;border-radius:8px;padding:18px 18px 16px;margin-bottom:14px}.head h2{margin:0 0 4px;font-size:26px;color:#fff}.head p{margin:0;opacity:.92;font-size:15px}'+
'.pbar{height:9px;background:rgba(255,255,255,.25);border-radius:9px;overflow:hidden;margin-top:12px}.pbar i{display:block;height:100%;width:0;background:#ffd166;transition:width .4s}.head small{display:block;margin-top:6px;font-size:13px;opacity:.9}'+
'details.toc{background:var(--card);border:1px solid var(--line);border-radius:8px;margin-bottom:18px}details.toc>summary{cursor:pointer;padding:12px 16px;font-weight:700}'+
'.toc .lst{padding:0 12px 12px;font-size:15px}.toc h5{margin:10px 4px 4px;font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}'+
'.toc a{display:flex;gap:8px;padding:4px 6px;border-radius:6px;text-decoration:none;color:var(--ink);line-height:1.35}.toc a:hover{background:var(--c2)}'+
'.toc .ck{flex:0 0 14px;height:14px;margin-top:3px;border-radius:50%;border:2px solid var(--line)}.toc a.done .ck{background:var(--okc);border-color:var(--okc)}'+
'.level{margin-bottom:26px}.level-head{display:flex;gap:12px;align-items:center;background:var(--card);border:1px solid var(--line);border-left:6px solid var(--c);border-radius:8px;padding:14px 16px;margin-bottom:14px}'+
'.level-head .badge{font-weight:800;font-size:12px;padding:4px 10px;border-radius:99px;color:#fff;white-space:nowrap}.lv-1 .badge{background:#2e9e5b}.lv-2 .badge{background:#d98a00}.lv-3 .badge{background:#b3261e}'+
'.level-head h2{margin:0;font-size:21px}.level-head p{margin:2px 0 0;color:var(--muted);font-size:15px}'+
'.lesson,.quiz-block{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:20px 18px;margin-bottom:16px}.quiz-block{border-top:5px solid #ffd166}'+
'.lesson>h3{margin:0 0 4px;font-size:20px;color:var(--c);display:flex;gap:10px;align-items:baseline}.lesson>h3 .n{background:var(--c2);border-radius:6px;padding:0 8px;font-size:15px}'+
'.quiz-block>h3{margin:0 0 4px;font-size:20px}.lesson h4{margin:20px 0 6px;font-size:17px}.obj{color:var(--muted);font-size:15px;margin:0 0 12px}.obj b{color:var(--ink)}'+
'p{margin:8px 0}ol,ul{padding-left:22px;margin:8px 0}li{margin:4px 0}'+
'ol.steps{list-style:none;counter-reset:s;padding:0}ol.steps>li{counter-increment:s;position:relative;padding:5px 0 5px 40px}ol.steps>li::before{content:counter(s);position:absolute;left:0;top:4px;width:27px;height:27px;border-radius:50%;background:var(--c);color:#fff;font-weight:800;display:grid;place-items:center;font-size:14px}'+
'kbd{font-family:ui-monospace,Consolas,monospace;font-size:.8em;background:var(--c2);border:1px solid var(--line);border-bottom-width:3px;border-radius:5px;padding:1px 6px;white-space:nowrap;color:var(--ink)}'+
'code{font-family:ui-monospace,Consolas,monospace;font-size:.86em;background:var(--c2);padding:1px 5px;border-radius:4px;overflow-wrap:anywhere}.path{font-weight:700;color:var(--c)}'+
'.box{border-radius:8px;padding:11px 14px 11px 48px;margin:12px 0;position:relative;font-size:15.5px;border:1px solid var(--line)}.box::before{position:absolute;left:13px;top:9px;font-size:20px}.box b:first-child{display:block}'+
'.box.tip{background:color-mix(in srgb,#1e8e3e 11%,var(--card))}.box.tip::before{content:"💡"}.box.warn{background:color-mix(in srgb,#e0a100 14%,var(--card))}.box.warn::before{content:"⚠️"}'+
'.box.ex{background:var(--c2);border:1px dashed var(--c)}.box.ex::before{content:"✍️"}.box.info{background:color-mix(in srgb,#2b6be0 10%,var(--card))}.box.info::before{content:"ℹ️"}'+
'figure.fig{margin:16px 0;text-align:center}figure.fig svg{max-width:100%;height:auto;background:#fff;border:1px solid var(--line);border-radius:8px;padding:8px}figure.fig figcaption{font-size:14px;color:var(--muted);margin-top:6px}figure.fig figcaption b{color:var(--ink)}'+
'.tw{overflow-x:auto}table.t{border-collapse:collapse;width:100%;margin:10px 0;font-size:15px}table.t th,table.t td{border:1px solid var(--line);padding:6px 9px;text-align:left;vertical-align:top}table.t th{background:var(--c2)}'+
'.done-row{margin-top:16px;padding-top:12px;border-top:1px solid var(--line);display:flex;justify-content:flex-end}'+
'.btn{font:inherit;font-weight:700;border:0;border-radius:8px;padding:9px 16px;cursor:pointer;background:var(--c);color:#fff}.btn.isdone{background:var(--okc)}'+
'.q{border:1px solid var(--line);border-radius:8px;padding:10px 14px;margin:10px 0}.q p{margin:0 0 6px;font-weight:700}.q label{display:block;padding:6px 8px;border-radius:6px;cursor:pointer}'+
'.q label.right{background:color-mix(in srgb,var(--okc) 18%,var(--card));outline:2px solid var(--okc)}.q label.wrong{background:color-mix(in srgb,var(--koc) 18%,var(--card));outline:2px solid var(--koc)}'+
'.q .exp{display:none;font-size:14.5px;color:var(--muted);margin-top:6px}.q.answered .exp{display:block}.score{font-weight:800;margin-left:10px}'+
'button:focus-visible,a:focus-visible,summary:focus-visible{outline:3px solid var(--c);outline-offset:2px}'+
'@media(max-width:600px){.lesson,.quiz-block{padding:16px 13px}.level-head{flex-direction:column;align-items:flex-start}}';

window.FI_render=function(host,html,key){
  var K='fi-'+key,st={};try{st=JSON.parse(localStorage.getItem(K)||'{}')||{}}catch(e){}
  function save(){try{localStorage.setItem(K,JSON.stringify(st))}catch(e){}}
  var R=host.shadowRoot||host.attachShadow({mode:'open'});
  R.innerHTML='<style>'+CSS+'</style><div class="head"><h2>Cours illustré</h2><p>Leçons détaillées avec schémas, exercices et quiz, du niveau débutant au niveau avancé.</p><div class="pbar"><i></i></div><small></small></div>'+
    '<details class="toc"><summary>Sommaire du cours illustré</summary><div class="lst"></div></details><div class="body">'+html+'</div>';
  R.querySelectorAll('table.t').forEach(function(t){var w=document.createElement('div');w.className='tw';t.parentNode.insertBefore(w,t);w.appendChild(t)});
  var lst=R.querySelector('.lst'),les=[].slice.call(R.querySelectorAll('.lesson'));
  function go(id){var el=R.getElementById(id);if(el)el.scrollIntoView({behavior:'smooth',block:'start'})}
  R.querySelectorAll('.level').forEach(function(lv){var h=document.createElement('h5');h.textContent=lv.dataset.label||'';lst.appendChild(h);
    lv.querySelectorAll('.lesson,.quiz-block').forEach(function(el){var a=document.createElement('a'),t=el.querySelector('h3');a.href='#';a.dataset.id=el.id;
      a.innerHTML='<span class="ck"></span><span></span>';a.lastChild.textContent=t?t.textContent.replace(/^\s*\d+\s*/,''):el.id;
      a.addEventListener('click',function(e){e.preventDefault();go(el.id)});lst.appendChild(a)})});
  function mark(id,d){var a=lst.querySelector('a[data-id="'+id+'"]');if(a)a.classList.toggle('done',!!d)}
  function prog(){var n=les.filter(function(l){return st[l.id]}).length,p=les.length?Math.round(n*100/les.length):0;
    R.querySelector('.pbar i').style.width=p+'%';R.querySelector('.head small').textContent='Votre progression : '+n+' / '+les.length+' leçons ('+p+' %)'}
  les.forEach(function(l){var row=document.createElement('div'),b=document.createElement('button');row.className='done-row';b.className='btn';b.type='button';row.appendChild(b);l.appendChild(row);
    function paint(){var d=!!st[l.id];b.textContent=d?'✓ Leçon terminée':'Marquer comme terminée';b.classList.toggle('isdone',d);mark(l.id,d);prog()}
    b.addEventListener('click',function(){st[l.id]=!st[l.id];save();paint()});paint()});
  R.querySelectorAll('.quiz-block').forEach(function(qb){var sc=qb.querySelector('.score');if(st[qb.id]!==undefined)mark(qb.id,1);
    qb.querySelector('.qcheck').addEventListener('click',function(){var g=0,qs=qb.querySelectorAll('.q');
      qs.forEach(function(q){var a=+q.dataset.a;q.classList.add('answered');q.querySelectorAll('label').forEach(function(lb,i){var c=lb.querySelector('input').checked;lb.classList.remove('right','wrong');if(i===a)lb.classList.add('right');else if(c)lb.classList.add('wrong');if(i===a&&c)g++})});
      sc.textContent='Score : '+g+' / '+qs.length+(g===qs.length?' 🎉 Excellent !':g>=qs.length/2?' 👍 Bien !':' : relisez les leçons');st[qb.id]=g;save();mark(qb.id,1)})});
  R.querySelectorAll('a[href="#top"]').forEach(function(a){a.remove()});
};
})();
