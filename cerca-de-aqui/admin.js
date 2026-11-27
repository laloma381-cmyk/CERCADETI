import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const db=createClient('https://cxdfejzmeqrjhzupdhdb.supabase.co','sb_publishable_ehPHgUjPgr89ECFdmcTufw_aoOPPx9R');
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let admin=false,user=null,editId=null,adminPage=0,total=0;
async function checkAdmin(){
 const {data}=await db.auth.getSession();user=data.session?.user||null;admin=false;
 if(user){const r=await db.rpc('cerca_is_admin');admin=!r.error&&r.data===true}
 const button=$('adminMenuButton');if(button)button.hidden=!admin;
 if(admin){await stats();await loadAdmin()}
}
window.openAdminCreate=()=>{
 if(!admin)return;
 editId=null;$('adminEditTitle').textContent='Añadir negocio';$('adminBusinessForm').reset();
 $('adminLocality').value='Pilar de la Horadada';$('adminPhotoUrl').value='';$('adminFormMessage').hidden=true;
 $('adminSaveButton').textContent='Publicar negocio';$('adminEditPanel').classList.add('show');
};
async function stats(){
 const {data,error}=await db.rpc('cerca_admin_dashboard_stats');
 if(error){$('adminStats').textContent='No se pudieron cargar las estadísticas.';console.error(error);return}
 const s=data||{};
 $('adminStats').innerHTML='<div class="admin-stat"><b>'+Number(s.active_listings||0)+'</b><span>NEGOCIOS ACTIVOS</span></div><div class="admin-stat"><b>'+Number(s.pending_listings||0)+'</b><span>SOLICITUDES PENDIENTES</span></div><div class="admin-stat"><b>'+Number(s.registered_users||0)+'</b><span>USUARIOS REGISTRADOS</span></div>';
}
async function loadAdmin(){
 if(!admin)return;
 $('adminListings').textContent='Cargando inventario…';
 const {data,error,count}=await db.from('cerca_listings').select('id,title,category,locality,plan,payment_status,publication_status,created_at,is_featured,created_by_admin',{count:'exact'}).order('created_at',{ascending:false}).range(adminPage*20,adminPage*20+19);
 if(error){$('adminListings').textContent='No se pudo cargar el inventario. Inténtalo de nuevo.';console.error(error);return}
 total=count||0;
 $('adminListings').innerHTML=(data||[]).length?data.map(x=>{
  const pending=x.publication_status==='pending',active=x.publication_status==='published';
  return '<article class="admin-row"><b>'+esc(x.title)+'</b><p class="business-meta">'+esc(x.locality)+' · '+esc(x.category)+' · '+(x.created_by_admin?'Ficha del administrador':'Anuncio contratado')+'</p><p class="business-meta">Estado: '+esc(x.publication_status)+' · '+esc(x.payment_status)+(x.is_featured?' · ⭐ Destacado':'')+'</p><div class="admin-actions">'+(pending?'<button onclick="reviewListing(\''+x.id+'\',true)">Aprobar</button><button class="danger" onclick="reviewListing(\''+x.id+'\',false)">Rechazar</button>':'')+'<button onclick="editAdminListing(\''+x.id+'\')">Editar</button><button onclick="toggleAdminFeatured(\''+x.id+'\','+(!x.is_featured)+')">'+(x.is_featured?'Quitar destacado':'Destacar')+'</button><button onclick="toggleAdminStatus(\''+x.id+'\',\''+(active?'blocked':'published')+'\')">'+(active?'Pausar':'Activar')+'</button><button class="danger" onclick="deleteAdminListing(\''+x.id+'\')">Eliminar</button></div></article>';
 }).join(''):'<div class="empty"><b>El inventario está vacío</b>Añade el primer negocio con el botón superior.</div>';
 const pages=Math.max(1,Math.ceil(total/20));$('adminPageInfo').textContent='Página '+(adminPage+1)+' de '+pages;$('adminPrev').disabled=adminPage===0;$('adminNext').disabled=adminPage>=pages-1;$('adminPagination').style.display=pages>1?'flex':'none';
}
window.loadAdmin=loadAdmin;window.loadAdminStats=stats;
window.changeAdminPage=delta=>{adminPage=Math.max(0,Math.min(Math.max(0,Math.ceil(total/20)-1),adminPage+delta));loadAdmin()};
window.reviewListing=async(id,approve)=>{if(!admin)return;const {error}=await db.rpc('cerca_admin_review_listing',{p_listing_id:id,p_approve:approve});if(error){alert('No se pudo revisar la solicitud.');return}await stats();await loadAdmin();if(window.loadListings)await window.loadListings()};
window.editAdminListing=async id=>{
 if(!admin)return;
 const {data,error}=await db.from('cerca_listings').select('id,title,category,locality,address,description,contact_phone,photo_url,opening_hours,is_featured').eq('id',id).single();
 if(error){alert('No se pudo abrir la ficha.');return}
 editId=id;$('adminEditTitle').textContent='Editar negocio';$('adminTitle').value=data.title||'';$('adminCategory').value=data.category||'Servicios';$('adminLocality').value=data.locality||'';$('adminAddress').value=data.address||'';$('adminPhone').value=data.contact_phone||'';$('adminHours').value=data.opening_hours||'';$('adminDescription').value=data.description||'';$('adminFeatured').checked=!!data.is_featured;$('adminPhotoUrl').value=data.photo_url||'';$('adminPhoto').value='';$('adminFormMessage').hidden=true;$('adminSaveButton').textContent='Guardar cambios';$('adminEditPanel').classList.add('show');
};
async function photoUrl(file){
 if(!file)return $('adminPhotoUrl').value||null;
 if(file.size>5*1024*1024)throw new Error('La foto supera el límite de 5 MB.');
 if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa una foto JPG, PNG o WebP.');
 const ext=file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg';
 const path=user.id+'/'+Date.now()+'-'+Math.random().toString(36).slice(2)+'.'+ext;
 const {error}=await db.storage.from('cerca-business-photos').upload(path,file,{contentType:file.type,upsert:false});
 if(error)throw error;
 return db.storage.from('cerca-business-photos').getPublicUrl(path).data.publicUrl;
}
async function geo(address,locality){
 const url='https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q='+encodeURIComponent(address+', '+locality+', España');
 const res=await fetch(url);if(!res.ok)throw new Error('Geolocalización no disponible');
 const data=await res.json();return data.length?{latitude:Number(data[0].lat),longitude:Number(data[0].lon)}:null;
}
window.saveAdminBusiness=async e=>{
 e.preventDefault();if(!admin)return;
 const btn=$('adminSaveButton'),msg=$('adminFormMessage');btn.disabled=true;msg.hidden=true;
 try{
  const photo_url=await photoUrl($('adminPhoto').files[0]);
  let coords=null;try{coords=await geo($('adminAddress').value.trim(),$('adminLocality').value.trim())}catch(err){console.warn(err)}
  const payload={title:$('adminTitle').value.trim(),category:$('adminCategory').value,locality:$('adminLocality').value.trim(),address:$('adminAddress').value.trim(),contact_phone:$('adminPhone').value.trim(),opening_hours:$('adminHours').value.trim(),description:$('adminDescription').value.trim()||'Negocio local de Cerca de Ti.',photo_url:photo_url||'',is_featured:$('adminFeatured').checked,latitude:coords?coords.latitude:null,longitude:coords?coords.longitude:null};
  const result=editId?await db.rpc('cerca_admin_update_listing',{p_listing_id:editId,p_listing:payload}):await db.rpc('cerca_admin_create_listing',{p_listing:payload});
  if(result.error)throw result.error;
  $('adminEditPanel').classList.remove('show');await stats();await loadAdmin();if(window.loadListings)await window.loadListings();
 }catch(err){console.error(err);msg.textContent=err.message||'No se pudo guardar el negocio.';msg.hidden=false}
 finally{btn.disabled=false;btn.textContent=editId?'Guardar cambios':'Publicar negocio'}
};
window.toggleAdminFeatured=async(id,value)=>{if(!admin)return;const {error}=await db.rpc('cerca_admin_update_listing',{p_listing_id:id,p_listing:{is_featured:value}});if(error){alert('No se pudo actualizar el destacado.');return}await loadAdmin();if(window.loadListings)await window.loadListings()};
window.toggleAdminStatus=async(id,status)=>{if(!admin)return;const {error}=await db.rpc('cerca_admin_set_listing_status',{p_listing_id:id,p_status:status});if(error){alert('No se pudo cambiar el estado.');return}await stats();await loadAdmin();if(window.loadListings)await window.loadListings()};
window.deleteAdminListing=async id=>{if(!admin||!confirm('¿Eliminar definitivamente este negocio y su solicitud asociada?'))return;const {error}=await db.rpc('cerca_admin_delete_listing',{p_listing_id:id});if(error){alert('No se pudo eliminar el negocio.');return}await stats();await loadAdmin();if(window.loadListings)await window.loadListings()};
db.auth.onAuthStateChange(()=>setTimeout(checkAdmin,200));
checkAdmin();
