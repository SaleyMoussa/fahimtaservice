// Fonctionnement hors connexion : les pages et fiches déjà ouvertes restent disponibles.
var V='fahimta-v1';
var BASE=['./','index.html','cours.html','espace.html','style.css','videos.css','app.js','config.js','stats.js','videos.js','manifest.webmanifest','icons/icon-192.png'];
self.addEventListener('install',function(e){e.waitUntil(caches.open(V).then(function(c){return c.addAll(BASE)}).then(function(){return self.skipWaiting()}))});
self.addEventListener('activate',function(e){e.waitUntil(caches.keys().then(function(k){return Promise.all(k.filter(function(x){return x!=V}).map(function(x){return caches.delete(x)}))}).then(function(){return self.clients.claim()}))});
self.addEventListener('fetch',function(e){var r=e.request,u=new URL(r.url);
 if(r.method!='GET'||u.origin!=location.origin)return;            // Supabase, YouTube… : jamais en cache
 if(r.mode=='navigate'||/\.html$/.test(u.pathname)){                // pages : réseau d'abord, copie sinon
  e.respondWith(fetch(r).then(function(x){var c=x.clone();caches.open(V).then(function(k){k.put(r,c)});return x})
   .catch(function(){return caches.match(r,{ignoreSearch:true}).then(function(m){return m||caches.match('index.html')})}));return}
 if(/\.(docx|pptx|xlsx|pdf|png|jpg|jpeg|svg)$/.test(u.pathname)){    // fichiers et images : copie d'abord
  e.respondWith(caches.match(r).then(function(m){return m||fetch(r).then(function(x){if(x.ok){var c=x.clone();caches.open(V).then(function(k){k.put(r,c)})}return x})}));return}
 e.respondWith(caches.match(r).then(function(m){var f=fetch(r).then(function(x){if(x.ok){var c=x.clone();caches.open(V).then(function(k){k.put(r,c)})}return x}).catch(function(){return m});return m||f}));
});
