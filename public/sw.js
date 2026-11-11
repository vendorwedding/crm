const V='crm-1.16.3',SHELL=['/','/index.html','/style.css','/app.js','/version.js','/config.js','/manifest.webmanifest','/icon-192.png','/icon-512.png'];
self.addEventListener('install',e=>e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(n=>n!==V&&n!=='data').map(n=>caches.delete(n)))).then(()=>clients.claim())));
self.addEventListener('fetch',e=>{const r=e.request,u=new URL(r.url);if(r.method!=='GET')return;
 const api=u.pathname.startsWith('/rest/v1/'),ok=(u.origin===location.origin&&SHELL.includes(u.pathname))||u.hostname==='cdn.jsdelivr.net'||api;if(!ok)return;
 // network-first; jika offline pakai salinan terakhir
 e.respondWith(fetch(r).then(res=>{if(res.ok){const c=res.clone();caches.open(api?'data':V).then(x=>x.put(r.url,c));return res}if(!api)return caches.match(r.url).then(m=>m||res);return res}).catch(()=>caches.match(r.url).then(m=>m||Response.error())))});
