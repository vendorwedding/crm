window.CFG={PUBLIC:'',API:'',URL:'https://vemlizysczqplrusnvoq.supabase.co',KEY:'sb_publishable_qDLygWLNIE_niR3pc0JrrQ_LI39mUll'};
// Kunci baru (sb_...) bukan JWT: kirim hanya lewat header "apikey", bukan "Authorization" (library lama mengirim keduanya -> "Invalid API key").
CFG.fetch=(u,o={})=>{const h=new Headers(o.headers);if((h.get('Authorization')||'').startsWith('Bearer sb_'))h.delete('Authorization');return fetch(u,{...o,headers:h})};
