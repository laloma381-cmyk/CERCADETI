import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const db=createClient('https://cxdfejzmeqrjhzupdhdb.supabase.co','sb_publishable_ehPHgUjPgr89ECFdmcTufw_aoOPPx9R');
const $=id=>document.getElementById(id);
let listings=[],filtered=[],category='Todos',featured=false,page=0,layer=null;
const pageSize=20;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm=v=>String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
function icon(cat){const c=norm(cat);if(/hostel|rest|cafe|bar|panader/.test(c))return'🍽️';if(/belleza|pelu|estet/.test(c))return'💇';if(/salud|farm|med/.test(c))return'💊';if(/comerc|tiend/.test(c))return'🛍️';if(/hogar|repar/.test(c))return'🛠️';if(/motor|taller/.test(c))return'🚗';return'🧑‍💼'}
function categoryOK(x){if(category==='Todos')return true;const c=norm(x.category),t=norm(x.title+' '+x.description);const groups={'Hostelería':['hosteleria','restaurante','cafeteria','bar','panaderia','comida'],'Belleza':['belleza','peluqueria','barberia','estetica'],'Salud':['salud','farmacia','clinica','medico','dentista'],'Tiendas':['tiendas','comercios','comercio','tienda','supermercado'],'Hogar':['hogar','fontanero','electricista','reformas'],'Motor':['motor','taller','automovil','mecanico','gasolinera'],'Servicios':['servicios','otros','profesional']};return (groups[category]||[]).some(k=>c.includes(k)||t.includes(k))}
function refreshFiltered(){
 const q=norm($('q')?.value);
 filtered=listings.filter(x=>categoryOK(x)&&(!featured||x.is_featured||x.plan==='featured')&&(!q||norm([x.title,x.category,x.locality,x.address,x.description].join(' ')).includes(q)));
 page=Math.min(page,Math.max(0,Math.ceil(filtered.length/pageSize)-1));
 render();
}
function render(){
 if(!$('cards'))return;
 const rows=filtered.slice(page*pageSize,(page+1)*pageSize);
 $('resultCount').textContent=filtered.length+' negocios encontrados';
 $('cards').innerHTML=rows.length?rows.map(x=>{
  const phone=String(x.contact_phone||'').replace(/[^0-9]/g,'');
  const map='https://www.google.com/maps/search/?api=1&query='+encodeURIComponent([x.address,x.locality].filter(Boolean).join(', '));
  const photo=x.photo_url?'<img class="business-photo" src="'+esc(x.photo_url)+'" alt="Foto de '+esc(x.title)+'" loading="lazy">':'<div class="business-photo business-fallback">'+icon(x.category)+'</div>';
  return '<article class="business-card">'+photo+'<div><h3>'+esc(x.title)+'</h3><span class="business-tag">'+esc(x.category)+'</span><p class="business-meta">📍 '+esc(x.locality)+'</p><p class="business-meta">🕒 '+esc(x.opening_hours||'Horario no facilitado')+'</p><p class="business-meta">'+(x.is_featured||x.plan==='featured'?'⭐ Destacado':'● Publicado')+'</p></div><div class="business-actions"><a href="https://wa.me/'+phone+'" target="_blank" rel="noopener">WhatsApp</a><a href="tel:'+esc(x.contact_phone)+'">Llamar</a><a href="'+map+'" target="_blank" rel="noopener">Cómo llegar</a></div></article>';
 }).join(''):'<div class="empty"><b>Aún no hay negocios en esta búsqueda</b>Prueba otra palabra o categoría. ¿Conoces un comercio que debería aparecer?<br><a class="action" href="contrata.html">Registrar un comercio</a></div>';
 const pages=Math.max(1,Math.ceil(filtered.length/pageSize));
 $('pageInfo').textContent='Página '+(page+1)+' de '+pages;
 $('prevPage').disabled=page===0;$('nextPage').disabled=page>=pages-1;
 $('listingPagination').style.display=pages>1?'flex':'none';
 updateMarkers(filtered);
}
function updateMarkers(rows){
 const map=window.cercaMap;if(!map||!window.L)return;
 if(!layer){layer=window.L.layerGroup().addTo(map)}
 layer.clearLayers();
 rows.forEach(x=>{if(x.latitude==null||x.longitude==null)return;const m=window.L.marker([Number(x.latitude),Number(x.longitude)]);m.bindPopup('<b>'+esc(x.title)+'</b><br>'+esc(x.locality)+(x.address?'<br>'+esc(x.address):''));layer.addLayer(m)});
}
async function load(){
 $('cards').innerHTML='<div class="empty"><b>Cargando negocios…</b>Actualizando el directorio.</div>';
 const {data,error}=await db.from('cerca_listings').select('id,title,category,locality,address,description,contact_phone,plan,starts_at,expires_at,latitude,longitude,photo_url,opening_hours,is_featured,created_by_admin').eq('publication_status','published').eq('payment_status','verified').lte('starts_at',new Date().toISOString()).gt('expires_at',new Date().toISOString()).order('is_featured',{ascending:false}).order('created_at',{ascending:false}).range(0,499);
 if(error){console.error('Cerca de Ti:',error);$('resultCount').textContent='Directorio temporalmente no disponible';$('cards').innerHTML='<div class="empty"><b>Estamos actualizando el directorio</b>Inténtalo de nuevo en unos segundos.<br><button class="action" onclick="loadListings()">Reintentar</button></div>';return}
 listings=data||[];refreshFiltered();
}
window.loadListings=load;
window.searchListings=()=>{
 if($('q').value.trim()&&category!=='Todos'){category='Todos';document.querySelectorAll('.chip').forEach(b=>b.classList.toggle('active',b.dataset.cat==='Todos'));document.querySelectorAll('.category-option').forEach(b=>b.classList.toggle('active',b.dataset.cat==='Todos'))}
 page=0;refreshFiltered();
};
window.changePage=delta=>{const pages=Math.max(1,Math.ceil(filtered.length/pageSize));page=Math.max(0,Math.min(pages-1,page+delta));render()};
window.setTab=tab=>{document.querySelectorAll('.tab').forEach(b=>b.classList.remove('active'));featured=tab==='featured';$('tabFeatured').classList.toggle('active',featured);$('tabExplore').classList.toggle('active',!featured);$('listingTitle').textContent=featured?'Negocios destacados':'Negocios cerca de ti';page=0;refreshFiltered()};
document.addEventListener('click',e=>{
 const chip=e.target.closest('.chip');
 if(chip){e.preventDefault();e.stopImmediatePropagation();category=chip.dataset.cat||'Todos';featured=false;page=0;document.querySelectorAll('.chip').forEach(b=>b.classList.toggle('active',b===chip));document.querySelectorAll('.tab').forEach(b=>b.classList.remove('active'));$('tabExplore').classList.add('active');$('listingTitle').textContent=category==='Todos'?'Negocios cerca de ti':category+' cerca de ti';refreshFiltered();return}
 const option=e.target.closest('.category-option');
 if(option){e.preventDefault();e.stopImmediatePropagation();category=option.dataset.cat||'Todos';featured=false;page=0;document.querySelectorAll('.chip').forEach(b=>b.classList.toggle('active',b.dataset.cat===category));document.querySelectorAll('.category-option').forEach(b=>b.classList.toggle('active',b===option));$('listingTitle').textContent=category==='Todos'?'Negocios cerca de ti':category+' cerca de ti';refreshFiltered();closePanel('categoryPanel')}
},true);
db.auth.onAuthStateChange(()=>setTimeout(load,150));
load();
