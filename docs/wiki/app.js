/* A local-first, dependency-free field codex. No game process or network API. */
(() => {
  'use strict';
  const D = window.WIKI_CATALOG;
  const main = document.getElementById('main');
  if (!D) { main.innerHTML = '<div class="loading"><h1>The catalog is missing</h1><p>Keep catalog.js beside index.html. See README.md for the catalog build command.</p></div>'; return; }
  const entries = new Map(D.entries.map(e => [e.id, e]));
  const assets = new Map(D.assets.map(a => [a.id, a]));
  const mediaPaths = new Map(D.assets.map(a => [a.path, a]));
  const categories = new Map(D.categories.map(c => [c.id, c]));
  const factions = D.entries.filter(e => e.category === 'factions');
  const pageSize = 24;
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const words = s => String(s ?? '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  const url = path => '../../' + path.replace(/^res:\/\//, '').split('/').map(encodeURIComponent).join('/');
  const href = id => '#/' + (assets.has(id) ? 'asset/' : 'entry/') + encodeURIComponent(id);
  const lookup = id => entries.get(id) || assets.get(id);
  const number = n => Number(n).toLocaleString('en');
  const normalize = s => String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[_:/-]+/g, ' ');
  const storage = {get(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } }, set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* Session remains fully usable if storage is disabled. */ } }};
  let saved = new Set(storage.get('aurelion-wiki-saved', []).filter(id => lookup(id)));
  let compared = storage.get('aurelion-wiki-compare', []).filter(id => entries.get(id)?.category === 'units').slice(0, 3);
  let toastTimer;
  const searchText = new Map([...D.entries, ...D.assets].map(e => [e.id, normalize([e.name, e.id, e.description, e.category, e.group, ...(e.tags || []), entries.get(e.faction)?.name || ''].join(' '))]));
  const statHelp = {
    hp: 'Base health per creature in a stack.', attack: 'Base attack rating before commander and other modifiers.',
    defense: 'Base defense rating before commander and other modifiers.', speed: 'Base tactical movement allowance.',
    initiative: 'Base initiative used in battle turn ordering.', growth: 'Base recruitment growth; buildings and faction bonuses can modify it.',
    min_damage: 'Base minimum damage per creature.', max_damage: 'Base maximum damage per creature.',
    retaliations: 'Base available retaliations; ability rules and battle conditions still apply.'
  };
  const routeLink = (path, params = {}) => '#/' + path + (Object.keys(params).length ? '?' + new URLSearchParams(Object.entries(params).filter(([,v]) => v !== '' && v != null)) : '');
  function state() {
    const raw = location.hash.slice(2) || '';
    const cut = raw.indexOf('?');
    const path = cut < 0 ? raw : raw.slice(0, cut);
    return {path, params: new URLSearchParams(cut < 0 ? '' : raw.slice(cut + 1))};
  }
  function navigate(path, params = {}) { location.hash = routeLink(path, params).slice(1); }
  function toast(message) { const t = document.getElementById('toast'); t.textContent = message; t.classList.add('visible'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('visible'), 2500); }
  function catName(e) { return e.kind ? (e.kind === 'audio' ? 'Audio asset' : 'Artwork') : categories.get(e.category)?.name || 'Entry'; }
  function portrait(e) {
    if (e.portrait && mediaPaths.has(e.portrait.path)) return e.portrait;
    const candidate = e.data?.stacks?.[0]?.unit_id || e.data?.hero_id || e.data?.unit_ids?.[0] || e.data?.piece_ids?.[0] || e.faction;
    if (candidate && candidate !== e.id) return entries.get(candidate)?.portrait || null;
    return null;
  }
  function imageMarkup(media, alt = '', lazy = true) {
    if (!media || !mediaPaths.has(media.path)) return '<span class="eyebrow" aria-hidden="true">✦</span>';
    const a = mediaPaths.get(media.path);
    if (media.rect?.length === 4 && a.width && a.height) return `<svg class="sprite-preview" viewBox="${media.rect.map(Number).join(' ')}" role="img" aria-label="${esc(alt)}" style="width:90%;height:90%;stroke:none"><image href="${url(media.path)}" width="${a.width}" height="${a.height}"/></svg>`;
    return `<img src="${url(media.path)}" alt="${esc(alt)}" ${lazy ? 'loading="lazy"' : ''} decoding="async">`;
  }
  const wave = () => '<div class="sound-wave" aria-hidden="true">' + '<i></i>'.repeat(17) + '</div>';
  const link = id => entries.has(id) ? `<a href="${href(id)}">${esc(entries.get(id).name)}</a>` : esc(words(id));
  function card(e) {
    const isAudio = e.kind === 'audio' || e.category === 'sounds';
    const media = e.path && !isAudio ? {path: e.path} : portrait(e);
    const landscape = ['towns','campaigns'].includes(e.category) || (e.kind === 'art' && e.width > e.height * 1.5);
    const meta = e.kind ? `${e.path.split('.').pop().toUpperCase()} · ${size(e.bytes)}` : e.data?.tier ? `Tier ${e.data.tier}` : (entries.get(e.faction)?.name || 'The Reach');
    return `<a class="entry-card" href="${href(e.id)}"><div class="card-image${isAudio ? ' audio' : landscape ? ' landscape' : ''}">${isAudio ? wave() : imageMarkup(media, '')}</div><div class="card-body"><span class="card-kicker">${esc(catName(e))}${e.archive ? ' · Archive' : ''}</span><h3>${esc(e.name)}</h3><p>${esc(e.description)}</p></div><div class="card-meta"><span>${esc(meta)}</span><span aria-hidden="true">Explore ↗</span></div></a>`;
  }
  function size(bytes) { return bytes > 1048576 ? (bytes/1048576).toFixed(1) + ' MB' : bytes > 1024 ? Math.round(bytes/1024) + ' KB' : bytes + ' B'; }
  function home() {
    return `<section class="home-hero"><div class="hero-copy"><span class="eyebrow">AURELION REACH · THE COMPLETE FIELD CODEX</span><h1>A world of lore.<br><em>A kingdom of choices.</em></h1><p>Know your allies. Learn the old magic. Explore every creature, stronghold, relic and sound of the Reach.</p><div class="hero-actions"><a class="button primary" href="#/browse/factions">Open the compendium <span aria-hidden="true">→</span></a><a class="button" href="#/assets">Explore the assets</a></div></div><a class="hero-caption" href="${href('town_riverwatch')}">Riverwatch Hold · Embercourt League ↗</a></section>
      <div class="home-stats"><a href="#/browse/factions"><strong>6</strong> Factions</a><a href="#/browse/units"><strong>160</strong> Units</a><a href="#/browse/spells"><strong>119</strong> Spells</a><a href="#/assets?scope=all"><strong>${number(D.coverage.media)}</strong> Art &amp; audio files</a></div>
      <div class="shell"><section><div class="section-head"><div><span class="eyebrow">Choose a banner</span><h2>The powers of the Reach</h2></div><a class="text-link" href="#/browse/factions">Meet the factions →</a></div><div class="faction-grid">${factions.map(e => `<a class="faction-card" href="${href(e.id)}">${imageMarkup(portrait(e))}<h3>${esc(e.name)}</h3></a>`).join('')}</div></section>
      <section><div class="section-head"><div><span class="eyebrow">From the field</span><h2>Begin your expedition</h2></div><a class="text-link" href="#/guide">Read the field guide →</a></div><div class="feature-grid">${[['hero_lyra','The pathfinder'],['unit_river_guard','Hold the line'],['spell_cinder_burst','Command the flame']].map(([id,title]) => {const e=entries.get(id);return `<a class="feature-card" href="${href(id)}">${imageMarkup(portrait(e))}<div><span class="eyebrow">${esc(title)}</span><h3>${esc(e.name)}</h3><p>${esc(e.description)}</p></div></a>`;}).join('')}</div></section>
      <section><div class="section-head"><div><span class="eyebrow">The complete collection</span><h2>Find your next discovery</h2></div><span class="small muted">${number(D.entries.length)} authored entries</span></div><div class="home-index">${D.categories.map(c=>`<a class="index-link" href="#/browse/${c.id}">${esc(c.name)}<span>${number(c.count)} ↗</span></a>`).join('')}</div></section></div>`;
  }
  function sidebar(selected) { return `<aside class="side-nav" aria-label="Compendium categories"><h2>The archives</h2>${D.categories.map(c=>`<a href="#/browse/${c.id}" class="${selected === c.id ? 'selected' : ''}" ${selected===c.id?'aria-current="page"':''}>${esc(c.name)}<span>${c.count}</span></a>`).join('')}<a href="#/assets" class="${selected==='assets'?'selected':''}">Asset library<span>${number(D.assets.length)}</span></a></aside>`; }
  function options(list, selected, empty) { return (empty === null ? '' : `<option value="">${esc(empty)}</option>`) + list.map(v => {const [id,label] = Array.isArray(v) ? v : [v, words(v)]; return `<option value="${esc(id)}" ${selected===String(id)?'selected':''}>${esc(label)}</option>`;}).join(''); }
  function select(name, label, list, selected, empty) { return `<div class="filter"><label for="filter-${name}">${esc(label)}</label><select id="filter-${name}" name="${name}">${options(list, selected, empty)}</select></div>`; }
  function matches(e, q) { const text = searchText.get(e.id); return normalize(q).split(/\s+/).filter(Boolean).every(token=>text.includes(token)); }
  function browse(path, p) {
    const allAssets = path === 'assets', search = path === 'search', bookmarked = path === 'saved';
    const category = path.startsWith('browse/') ? path.slice(7) : '';
    if (category && !categories.has(category)) return missing();
    const c = categories.get(category);
    const title = allAssets ? 'The asset library' : search ? 'Search the codex' : bookmarked ? 'Your saved discoveries' : c.name;
    const intro = allAssets ? 'Artwork, music and sounds, with their roles and connections. Explore presentation files or open the source archives.' : search ? 'Search names, abilities, descriptions and file names across the entire collection.' : bookmarked ? 'A personal field journal, stored in this browser.' : c.description;
    let source = allAssets ? D.assets : search ? [...D.entries, ...D.assets] : bookmarked ? [...saved].map(lookup) : D.entries.filter(e=>e.category===category);
    const q = p.get('q') || '', faction = p.get('faction') || '', tag = p.get('tag') || '', tier = p.get('tier') || '', kind = p.get('kind') || '', group = p.get('group') || '';
    const scope = p.get('scope') || (allAssets ? 'presentation' : 'all');
    let rows = source.filter(e => (!q || matches(e,q)) && (!faction || e.faction===faction) && (!tag || e.tags?.includes(tag)) && (!tier || String(e.data?.tier)===tier) && (!kind || (kind==='entries' ? !e.kind : e.kind===kind)) && (!group || e.group===group) && (scope==='all' || (scope==='archive' ? e.archive : !e.archive)));
    const sort = p.get('sort') || 'name';
    rows.sort((a,b) => {
      if (q) { const exact = normalize(q); const score = e => normalize(e.name)===exact ? 0 : normalize(e.name).startsWith(exact) ? 1 : !e.kind ? 2 : 3; if (score(a)!==score(b)) return score(a)-score(b); }
      if (sort==='tier') return (a.data?.tier || 0)-(b.data?.tier || 0) || a.name.localeCompare(b.name);
      if (sort==='size') return (b.bytes || 0)-(a.bytes || 0);
      return a.name.localeCompare(b.name) || a.id.localeCompare(b.id);
    });
    const pages = Math.max(1,Math.ceil(rows.length/pageSize)), page = Math.min(pages,Math.max(1,Number(p.get('page')) || 1));
    const start = (page-1)*pageSize;
    const tags = [...new Set(source.flatMap(e=>e.tags || []))].sort();
    const filters = `<form class="filters" id="browse-filters" data-path="${esc(path)}"><div class="filter query"><label for="filter-q">Search ${allAssets?'files':'entries'}</label><input type="search" id="filter-q" name="q" value="${esc(q)}" placeholder="Name, role, ability…"></div>
      ${!allAssets && !search && source.some(e=>e.faction) ? select('faction','Banner',[...factions.map(f=>[f.id,f.name]),...new Set(source.map(e=>e.faction).filter(f=>f&&!entries.has(f)))].map(f=>Array.isArray(f)?f:[f,words(f.replace(/^faction_/,''))]),faction,'All factions') : ''}
      ${allAssets || search || bookmarked ? select('kind','Collection',search || bookmarked ? [['entries','Compendium'],['art','Artwork'],['audio','Audio']] : [['art','Artwork'],['audio','Audio']],kind,'Everything') : ''}
      ${allAssets ? select('group','Asset family',[...new Set(D.assets.map(a=>a.group))].sort(),group,'All families') + select('scope','Edition',[['presentation','Presentation files'],['archive','Source & archive'],['all','All files']],scope,null) : ''}
      ${category==='units' || category==='spells' ? select('tier','Tier',[...new Set(source.map(e=>e.data.tier))].sort((a,b)=>a-b).map(t=>[t,'Tier '+t]),tier,'All tiers') : ''}
      ${!allAssets && !search && !bookmarked && tags.length ? select('tag',category==='spells'?'School / role':'Role / type',tags,tag,'All types') : ''}
      ${select('sort','Order',allAssets?[['name','Name A–Z'],['size','Largest files']]:[['name','Name A–Z'],['tier','Tier']],sort,null)}<button class="button" type="submit">Find →</button></form>`;
    return `<div class="shell browse-layout">${sidebar(allAssets?'assets':category)}<section><div class="browse-head"><div><span class="eyebrow">${allAssets?'The creative archives':bookmarked?'Your field journal':'The compendium'}</span><h1>${esc(title)}</h1><p>${esc(intro)}</p></div></div>${filters}<div class="result-line"><span>${rows.length ? `${number(start+1)}–${number(Math.min(start+pageSize,rows.length))} of ` : ''}${number(rows.length)} results${q?' for “'+esc(q)+'”':''}</span><a class="text-link" href="${routeLink(path,allAssets?{scope:'all'}:{})}">Reset filters</a></div>
      ${rows.length?`<div class="results-grid">${rows.slice(start,start+pageSize).map(card).join('')}</div>`:empty(bookmarked?'Your journal is waiting':'No entries found',bookmarked?'Open any entry and choose Save entry to keep it here.':'Try a shorter search, another spelling, or reset the filters.')}
      ${pages>1?`<nav class="pagination" aria-label="Result pages">${page>1?`<a href="${routeLink(path,{...Object.fromEntries(p),page:page-1})}">← Previous</a>`:'<span aria-disabled="true">← Previous</span>'}<span>Page ${page} of ${pages}</span>${page<pages?`<a href="${routeLink(path,{...Object.fromEntries(p),page:page+1})}">Next →</a>`:'<span aria-disabled="true">Next →</span>'}</nav>`:''}</section></div>`;
  }
  function empty(title, description) { return `<div class="empty-state"><span class="eyebrow">✦</span><h2>${esc(title)}</h2><p>${esc(description)}</p><a class="button" href="#/browse/units">Explore the compendium</a></div>`; }
  function value(v, depth = 0) {
    if (v === null || v === undefined || v === '') return '<span class="muted">—</span>';
    if (typeof v === 'boolean') return v ? 'Yes' : 'No';
    if (typeof v === 'number') return esc(number(v));
    if (typeof v === 'string') return entries.has(v) ? link(v) : esc(v.includes('_') && !v.includes(' ') && !v.includes('/') ? words(v) : v);
    if (Array.isArray(v)) {
      if (!v.length) return '<span class="muted">None</span>';
      if (v.every(x=>typeof x!=='object')) return `<div class="inline-values">${v.map(x=>'<span>'+value(x,depth+1)+'</span>').join('')}</div>`;
      return v.map(item=>{
        const name = item.name || item.label || item.public_summary || item.summary;
        const desc = item.description || (item.summary!==name?item.summary:'');
        const rest = Object.fromEntries(Object.entries(item).filter(([k])=>!['name','label','description','summary','public_summary','id'].includes(k)));
        return `<div class="value-card">${name?`<h4>${esc(name)}</h4>`:''}${desc?`<p>${esc(desc)}</p>`:''}${Object.keys(rest).length?value(rest,depth+1):''}</div>`;
      }).join('');
    }
    if (depth>5) return esc(Object.entries(v).map(([k,x])=>words(k)+': '+(typeof x==='object'?'See authored reference':x)).join(' · '));
    return `<table class="data-table"><tbody>${Object.entries(v).filter(([k])=>!k.endsWith('sha256') && !['ai_hints','validation_tags','enemy_strategy','source_tags','schema','schema_id'].includes(k)).map(([k,x])=>`<tr><th scope="row">${entries.has(k)?link(k):esc(words(k))}</th><td>${value(x,depth+1)}</td></tr>`).join('')}</tbody></table>`;
  }
  const fields = {
    units: ['cost','abilities','spell_resistance_pct','control_resistance_pct','spell_school_resistance_pct','status_immunity_ids'],
    heroes: ['roster_summary','archetype','recruit_cost','base_movement','command','command_path','starting_specialties','specialty_focus_ids','battle_traits','starting_spell_ids'],
    factions: ['design_pillars','economy','recruitment'],
    towns: ['strategic_summary','economy','recruitment','logistics_plan','garrison','spell_library'],
    buildings: ['cost','requires','upgrade_from','income','unlock_unit_id','growth_bonus','spell_tier','readiness_bonus','pressure_bonus','recovery_relief','recruitment_discount_percent','market_profile','artifact_reward_contract','capital_project'],
    spells: ['context','school_id','tier','mana_cost','target_mode','primary_role','effect'],
    artifacts: ['slot','rarity','artifact_class','bonuses','bonus_metadata','equip_constraints','risk','accord_affinity','faction_affinity'],
    artifact_sets: ['source_hint','piece_thresholds','runtime_policy'],
    resources: ['category','market_tier','stockpile','material_cue','legacy_aliases'],
    resource_sites: ['action_label','rewards','claim_rewards','control_income','control_income_cadence','claim_recruits','weekly_recruits','learn_spell_id','learn_spell_ids','service_summary','service_cost','service_effects','visit_cooldown_days','persistent_control','guarded','neutral_roster','town_support','transit_profile','shrine_effects','hero_command_bonus','vision_radius','sign_text','public_text','guarded_reward_contract','dwelling_contract','scouting_contract','route_lock_contract','runtime_boundary'],
    map_objects: ['family','footprint','passable','visitable','passability_class','interaction','approach','map_roles','runtime_boundary'],
    neutral_dwellings: ['summary','content_status'],
    army_groups: ['stacks'], encounters: ['terrain','max_rounds','battlefield_tags','enemy_commander','field_objectives','rewards'],
    biomes: ['movement_cost','sight_modifier','passable','battle_terrain','route_roles','allowed_site_families','decoration_palette','blocker_palette'],
    terrain: ['terrain_group','readability_role','variant_keys','layer','style'],
    campaigns: ['arc_goal','region','scenarios','completion_title','completion_summary'],
    scenarios: ['selection','map_size','starting_resources','objectives','hero_starts'],
    sounds: ['role','duration_msec','volume_db','repeat_cooldown_msec','priority_class','playback_mode'],
    effects: ['render_mode','scale','duration_msec','color','blend_mode']
  };
  const friendly = {hp:'Health',min_damage:'Minimum damage',max_damage:'Maximum damage',growth:'Weekly growth',spell_resistance_pct:'Spell resistance (%)',control_resistance_pct:'Control resistance (%)',spell_school_resistance_pct:'School resistance (%)',status_immunity_ids:'Status immunities',requires:'Prerequisites',unlock_unit_id:'Recruitment unlocked',growth_bonus:'Additional weekly recruits',income:'Daily income',mana_cost:'Mana cost',volume_db:'Mix level (dB)',duration_msec:'Duration (ms)',repeat_cooldown_msec:'Repetition cooldown (ms)',runtime_boundary:'Authored availability notes',content_status:'Authored content status'};
  function field(key, data) { if(key==='runtime_boundary')return `<details class="source-details"><summary>Authored availability notes</summary>${value(data)}</details>`; return `<section class="field rich-value"><h3>${esc(friendly[key]||words(key))}</h3>${typeof data==='string' && !entries.has(data)?`<p>${value(data)}</p>`:value(data)}</section>`; }
  function referenceList(ids) { return `<div class="reference-list">${ids.map(id=>{const e=entries.get(id);if(!e)return '';return `<a href="${href(id)}">${portrait(e)?imageMarkup(portrait(e)) : ''}<span><strong>${esc(e.name)}</strong><small>${esc(catName(e))}${e.data.tier?' · Tier '+e.data.tier:''}</small></span></a>`;}).join('')}</div>`; }
  function relationships(e) {
    const groups = {...e.relations};
    if(e.faction) groups.Faction=[e.faction];
    const incoming = D.entries.filter(other=>other.id!==e.id && Object.values(other.relations).some(ids=>ids.includes(e.id)));
    if(incoming.length) groups['Also found in']=incoming.map(e=>e.id);
    return Object.entries(groups).map(([name,ids])=>`<section class="relationship-group"><h3>${esc(name)} <span class="muted">(${ids.length})</span></h3>${referenceList(ids.slice(0,8))}${ids.length>8?`<details><summary>Show ${ids.length-8} more</summary>${referenceList(ids.slice(8))}</details>`:''}</section>`).join('') || '<p class="small muted">No authored content links for this entry.</p>';
  }
  function statBlock(e) {
    const d=e.data;
    const keys=e.category==='units'?['hp','attack','defense','speed','initiative','growth','min_damage','max_damage']:e.category==='heroes'?['base_movement']:e.category==='spells'?['tier','mana_cost']:[];
    return keys.length?`<div class="stats">${keys.map(k=>`<div class="stat" title="${esc(statHelp[k]||friendly[k]||words(k))}"><strong>${esc(d[k]??'—')}</strong><span>${esc(friendly[k]||words(k))}</span></div>`).join('')}</div>`:'';
  }
  function saveButton(id) { return `<button class="button" data-save="${esc(id)}" aria-pressed="${saved.has(id)}">${saved.has(id)?'◆ Saved':'◇ Save entry'}</button>`; }
  function mediaStrip(items) {
    return `<div class="media-strip">${items.map(m=>{const a=mediaPaths.get(m.path);if(!a)return '';return `<a class="media-tile" href="${href(a.id)}"><div class="card-image${a.kind==='audio'?' audio':''}">${a.kind==='audio'?wave():imageMarkup(m)}</div><span class="media-name">${esc(m.role || a.name)}</span></a>`;}).join('')}</div>`;
  }
  function audioPlayer(path) { return `<audio class="audio-player" controls preload="none" src="${url(path)}">Your browser cannot play this format. <a href="${url(path)}">Open the audio file</a>.</audio><p class="audio-note muted">Playback starts only when you press play. <a class="text-link" href="${url(path)}" target="_blank" rel="noopener">Open audio file ↗</a></p>`; }
  const terrainColors = {grass:'#728655',forest:'#39543b',dirt:'#927452',sand:'#c6ae74',water:'#477f8a',mire:'#61745a',swamp:'#61745a',snow:'#c5d4d1',rough:'#847663',lava:'#9c5a3e',underground:'#59566a'};
  function mapMarkup(d) {
    if (!Array.isArray(d.map) || !d.map.length || !Array.isArray(d.map[0])) return '';
    const h=d.map.length,w=d.map[0].length,colors=new Set();
    const tiles=d.map.flatMap((row,y)=>row.map((t,x)=>{const name=typeof t==='string'?t:'grass';colors.add(name);return `<rect x="${x}" y="${y}" width="1.02" height="1.02" fill="${terrainColors[name]||'#6a745b'}"><title>${esc(words(name))} (${x}, ${y})</title></rect>`;})).join('');
    return `<section class="detail-section"><h2>At a glance: the map</h2><div class="map-preview"><svg role="img" aria-label="Authored terrain map" viewBox="0 0 ${w} ${h}">${tiles}${d.start?`<circle cx="${Number(d.start.x)+.5}" cy="${Number(d.start.y)+.5}" r=".3" fill="#f6d77b" stroke="#222" stroke-width=".07"><title>Starting position</title></circle>`:''}</svg><div class="map-legend">${[...colors].map(t=>`<span><i style="background:${terrainColors[t]||'#6a745b'}"></i>${esc(words(t))}</span>`).join('')}<span>● Starting position</span></div></div></section>`;
  }
  function detail(id) {
    const e=entries.get(id); if(!e)return missing();
    const d=e.data, media=portrait(e), isAudio=e.category==='sounds';
    const sections=(fields[e.category]||[]).filter(k=>d[k]!==undefined && d[k]!=='' && !(typeof d[k]==='object' && d[k]!==null && !Object.keys(d[k]).length));
    return `<article class="shell"><nav class="breadcrumbs" aria-label="Breadcrumb"><a href="#/">Codex</a><span>›</span><a href="#/browse/${e.category}">${esc(catName(e))}</a><span>›</span><span>${esc(e.name)}</span></nav><header class="detail-head"><div class="detail-art${['towns','campaigns'].includes(e.category)?' landscape':''}">${isAudio?wave():imageMarkup(media,e.name,false)}${media&&!isAudio?`<button data-zoom="${esc(media.path)}">Enlarge artwork ↗</button>`:''}</div><div class="detail-intro"><span class="eyebrow">${esc(catName(e))}${entries.has(e.faction)?' · '+esc(entries.get(e.faction).name):''}</span><h1>${esc(e.name)}</h1><p>${esc(e.description)}</p><div class="tags">${e.tags.map(t=>`<a class="tag" href="${routeLink('browse/'+e.category,{tag:t})}">${esc(words(t))}</a>`).join('')}</div>${statBlock(e)}${isAudio&&d.path?audioPlayer(d.path):''}<div class="detail-actions">${saveButton(id)}${e.category==='units'?`<button class="button" data-compare="${esc(id)}" aria-pressed="${compared.includes(id)}">${compared.includes(id)?'✓ In comparison':'+ Compare unit'}</button>`:''}<button class="button" data-copy>Copy entry link</button></div></div></header>
      <div class="detail-columns"><div><section class="detail-section"><h2>${e.category==='sounds'||e.category==='effects'?'Presentation details':'What it does'}</h2>${sections.map(k=>field(k,d[k])).join('')||'<p>This entry is defined by its related content and media below.</p>'}</section>${e.category==='scenarios'?mapMarkup(d):''}${e.media.length?`<section class="detail-section"><h2>Artwork &amp; sound <span class="small muted">${e.media.length} files</span></h2>${mediaStrip(e.media.slice(0,9))}${e.media.length>9?`<details class="source-details"><summary>Show all associated media</summary>${mediaStrip(e.media.slice(9))}</details>`:''}</section>`:''}<details class="source-details"><summary>Authored reference</summary><p class="small">Base values from the current content library. Scenario rules, commander bonuses and battle conditions can modify them.</p><p><code>${esc(e.id)}</code></p><a href="${url(e.source)}" target="_blank" rel="noopener">Open ${esc(e.source)} ↗</a></details></div><aside><section class="detail-section"><h2>Explore the connections</h2>${relationships(e)}</section></aside></div></article>`;
  }
  function assetDetail(id) {
    const a=assets.get(id);if(!a)return missing();
    return `<article class="shell"><nav class="breadcrumbs" aria-label="Breadcrumb"><a href="#/">Codex</a><span>›</span><a href="#/assets">Asset library</a><span>›</span><span>${esc(a.name)}</span></nav><header class="detail-head"><div class="detail-art asset-detail-image">${a.kind==='audio'?wave():imageMarkup({path:a.path},a.name,false)}${a.kind!=='audio'?`<button data-zoom="${esc(a.path)}">Enlarge artwork ↗</button>`:''}</div><div class="detail-intro"><span class="eyebrow">${esc(a.group)} · ${a.archive?'Source & archive':'Presentation library'}</span><h1>${esc(a.name)}</h1><p class="asset-description">${esc(a.description)}</p><div class="tags"><span class="tag">${esc(a.path.split('.').pop().toUpperCase())}</span><span class="tag">${size(a.bytes)}</span>${a.width?`<span class="tag">${a.width} × ${a.height}</span>`:''}</div>${a.kind==='audio'?audioPlayer(a.path):''}<div class="detail-actions">${saveButton(id)}<a class="button" href="${url(a.path)}" target="_blank" rel="noopener">Open original ↗</a><button class="button" data-copy>Copy entry link</button></div></div></header><div class="detail-columns"><section class="detail-section"><h2>What this asset represents</h2>${a.uses.length?referenceList(a.uses):'<p>No direct content association is declared. This file belongs to the '+esc(a.group)+' media collection; its filename and source references identify its production role.</p>'}<p class="small muted" style="margin-top:20px">Artwork and sound communicate game events. Their associated entries explain the underlying abilities and rules.</p></section><aside><section class="detail-section"><h2>File information</h2>${a.production?`<p class="small muted">${esc(a.production.role)} · ${esc(a.production.gesture||a.production.category)}</p><details class="source-details"><summary>Production brief</summary><p class="small">${esc(a.production.prompt)}</p><a href="${url(a.production.reference)}" target="_blank" rel="noopener">Original generation record ↗</a></details>`:''}${value({'File':a.path,'Collection':words(a.group),'Edition':a.archive?'Source / archive':'Presentation file','Size':size(a.bytes),...(a.width?{'Dimensions':a.width+' × '+a.height}:{}),'Roles':a.roles})}<details class="source-details"><summary>Referenced by ${a.files.length} files</summary><ul>${a.files.map(f=>`<li><a href="${url(f)}" target="_blank" rel="noopener">${esc(f)}</a></li>`).join('')}</ul></details></section></aside></div></article>`;
  }
  function compare() {
    const rows=compared.map(id=>entries.get(id));
    if(!rows.length)return `<div class="shell">${empty('Assemble your comparison','Open a unit and choose Compare unit. You can compare up to three units side by side.')}</div>`;
    const stats=['tier','hp','attack','defense','min_damage','max_damage','speed','initiative','retaliations','growth','ranged'];
    return `<section class="shell"><span class="eyebrow">Plan your army</span><h1>Units, side by side</h1><p>Base authored values per creature. This is a roster comparison, not a damage forecast.</p><div class="compare-scroll"><table class="compare-table"><thead><tr><th scope="col">${rows.length} / 3 units</th>${rows.map(e=>`<th scope="col">${imageMarkup(portrait(e))}<a href="${href(e.id)}">${esc(e.name)}</a><p class="small">${esc(entries.get(e.faction)?.name||'Neutral')}</p><button class="button" data-compare="${esc(e.id)}">Remove</button></th>`).join('')}</tr></thead><tbody>${stats.map(k=>{const max=Math.max(...rows.map(e=>typeof e.data[k]==='number'?e.data[k]:0));return `<tr><td title="${esc(statHelp[k]||'')}">${esc(friendly[k]||words(k))}</td>${rows.map(e=>`<td class="${typeof e.data[k]==='number'&&e.data[k]===max&&k!=='tier'?'best':''}">${value(e.data[k])}</td>`).join('')}</tr>`;}).join('')}<tr><td>Recruitment cost</td>${rows.map(e=>`<td class="rich-value">${value(e.data.cost)}</td>`).join('')}</tr><tr><td>Abilities</td>${rows.map(e=>`<td class="rich-value">${value(e.data.abilities)}</td>`).join('')}</tr></tbody></table></div><p class="small muted" style="margin-top:24px">Highlighted numbers are the largest values in this selection; they do not establish which unit is best in every situation.</p><a class="button" href="#/browse/units">Browse more units →</a></section>`;
  }
  function guide() {
    return `<article class="shell"><span class="eyebrow">For explorers and commanders</span><h1>A field guide to the codex</h1><p>Everything in one place, from a creature’s first strike to the art behind a distant stronghold.</p><div class="guide-grid">
      <article><h2>Follow the connections</h2><p>Every entry links to its related content. Start with a faction, meet its heroes and troops, then follow a building’s prerequisites or a spell in a hero’s starting book.</p><p>Use the category filters for faction, tier and role. Search understands names, descriptions, abilities and file names.</p><a class="text-link" href="#/browse/factions">Choose a faction →</a></article>
      <article><h2>Read the battlefield</h2><p>Unit pages show base health, damage, attack, defense, tactical speed and initiative. An army is made of stacks; the listed creature values are not the final damage of the whole stack. Commander bonuses, terrain, abilities and current conditions matter.</p><p>Save up to three units in a comparison to inspect their strengths, abilities and costs side by side.</p><a class="text-link" href="#/browse/units">Study the roster →</a></article>
      <article><h2>Build and recruit</h2><p>Building entries list construction costs, prerequisites, income and recruitment unlocks. Towns connect those buildings to their starting garrisons and spell libraries. Growth values describe the authored base; faction and building bonuses may change the final muster.</p><p>Town recruitment goes to a stationed hero or the town’s garrison. Recruitment from adventure sites requires a hero visit.</p><a class="text-link" href="#/browse/buildings">Explore town development →</a></article>
      <article><h2>Understand magic and relics</h2><p>Spell pages distinguish battle and overworld contexts and list mana cost, target mode and effect. Artifact pages list equipped bonuses, restrictions and risks. Artifact sets link matching pieces and their threshold bonuses.</p><p>Values are taken from current authored definitions. They are a reference to the content, not a promise that every item appears in every scenario.</p><a class="text-link" href="#/browse/spells">Open the spellbook →</a></article>
      <article><h2>Explore the creative archive</h2><p>The library contains ${number(D.coverage.art)} image files and ${number(D.coverage.audio)} audio files. Presentation files are shown first. Choose <em>Source &amp; archive</em> or <em>All files</em> to include production originals, alternatives and reference material.</p><p>Asset pages explain their presentation role and link associated game entries. Source or reference artwork is labelled and does not imply that it ships in the game. Import sidecars and generated cache files are not separate creative assets.</p><p>Press play to hear audio. Nothing autoplays; starting another recording pauses the previous one. Browser codec support varies, so every file also has an original-file link.</p><a class="text-link" href="#/assets?scope=all">Browse every asset →</a></article>
      <article><h2>Keep a field journal</h2><p>Choose <em>Save entry</em> on any content or asset page to bookmark it in this browser. Use <em>Copy entry link</em> for a direct link, and your browser’s Back button to return to the previous view.</p><ul><li><kbd>/</kbd> focuses the global search.</li><li><kbd>Enter</kbd> submits a search.</li><li><kbd>Tab</kbd> moves through links and controls.</li><li><kbd>Esc</kbd> closes an enlarged image.</li></ul><p>Saved entries stay on this device. If browser storage is unavailable, bookmarks work for the current session.</p></article>
      <article><h2>Where the knowledge comes from</h2><p>The codex is built from the game’s authored JSON, media manifests and direct scene references. Each entry links its original definition. Detailed availability notes are retained where the authored data distinguishes content from runtime support.</p><p>Edition: ${esc(D.edition)}. This edition includes ${number(D.coverage.entries)} content entries and ${number(D.coverage.media)} image/audio files. It is a companion reference; it does not run or modify the game.</p><a class="text-link" href="README.md" target="_blank" rel="noopener">Local setup and catalog updates ↗</a></article>
    </div></article>`;
  }
  function missing() { document.title='Entry not found — Aurelion Codex'; return `<div class="shell">${empty('This page is not in the archives','The link may be incomplete or refer to a different edition. Search the codex to find the entry.')}</div>`; }
  function updateTools() {
    document.getElementById('saved-count').textContent=saved.size;
    const tray=document.getElementById('compare-tray');
    tray.hidden=!compared.length || state().path==='compare';
    tray.innerHTML=compared.length?`<span>${compared.length} / 3 units selected</span><a class="button primary" href="#/compare">Compare units →</a><button data-clear-compare>Clear</button>`:'';
  }
  function render() {
    document.querySelectorAll('audio').forEach(a=>a.pause());
    const {path,params}=state();
    document.title='The Aurelion Codex — Aurelion Reach Wiki';
    try {
      if(!path) main.innerHTML=home();
      else if(path.startsWith('entry/')) {const id=decodeURIComponent(path.slice(6));main.innerHTML=detail(id);if(entries.has(id))document.title=entries.get(id).name+' — Aurelion Codex';}
      else if(path.startsWith('asset/')) {const id=decodeURIComponent(path.slice(6));main.innerHTML=assetDetail(id);if(assets.has(id))document.title=assets.get(id).name+' — Aurelion Codex';}
      else if(path.startsWith('browse/') || ['assets','search','saved'].includes(path)) main.innerHTML=browse(path,params);
      else if(path==='compare') main.innerHTML=compare();
      else if(path==='guide') main.innerHTML=guide();
      else main.innerHTML=missing();
    } catch(error) { main.innerHTML=missing(); console.error('Could not render wiki route',error); }
    document.querySelectorAll('[data-nav]').forEach(a=>a.classList.toggle('active',a.dataset.nav===(path==='guide'?'guide':path.startsWith('asset')?'assets':path?'compendium':'')));
    document.getElementById('global-query').value=path==='search'?(params.get('q')||''):'';
    updateTools();
    window.scrollTo({top:0,behavior:'instant'});
    main.focus({preventScroll:true});
  }
  document.addEventListener('submit',event=>{
    if(event.target.id==='global-search'){event.preventDefault();navigate('search',{q:document.getElementById('global-query').value.trim()});}
    if(event.target.id==='browse-filters'){event.preventDefault();navigate(event.target.dataset.path,Object.fromEntries([...new FormData(event.target)].filter(([,v])=>v)));}
  });
  document.addEventListener('change',event=>{if(event.target.matches('#browse-filters select'))event.target.form.requestSubmit();});
  document.addEventListener('click',async event=>{
    if(event.target.closest('.skip-link')){event.preventDefault();main.focus();main.scrollIntoView();return;}
    const save=event.target.closest('[data-save]');
    if(save){const id=save.dataset.save;if(saved.has(id))saved.delete(id);else saved.add(id);storage.set('aurelion-wiki-saved',[...saved]);save.setAttribute('aria-pressed',saved.has(id));save.textContent=saved.has(id)?'◆ Saved':'◇ Save entry';updateTools();toast(saved.has(id)?'Added to your field journal':'Removed from your field journal');}
    const button=event.target.closest('[data-compare]');
    if(button){const id=button.dataset.compare;if(compared.includes(id))compared=compared.filter(x=>x!==id);else if(compared.length<3)compared.push(id);else{toast('Compare up to three units. Remove one to add another.');return;}storage.set('aurelion-wiki-compare',compared);if(state().path==='compare')render();else{button.setAttribute('aria-pressed',compared.includes(id));button.textContent=compared.includes(id)?'✓ In comparison':'+ Compare unit';updateTools();}}
    if(event.target.closest('[data-clear-compare]')){compared=[];storage.set('aurelion-wiki-compare',compared);updateTools();document.querySelectorAll('[data-compare]').forEach(b=>{b.textContent='+ Compare unit';b.setAttribute('aria-pressed','false');});}
    if(event.target.closest('[data-copy]')){try{await navigator.clipboard.writeText(location.href);toast('Entry link copied');}catch{toast('Copy this entry’s URL from the address bar.');}}
    const zoom=event.target.closest('[data-zoom]');
    if(zoom){const a=mediaPaths.get(zoom.dataset.zoom);if(a){const dialog=document.getElementById('image-dialog');document.getElementById('image-dialog-content').innerHTML=imageMarkup({path:a.path},a.name,false)+`<p>${esc(a.name)} · <a class="text-link" href="${url(a.path)}" target="_blank" rel="noopener">Open original ↗</a></p>`;dialog.showModal();}}
    if(event.target.closest('.dialog-close'))document.getElementById('image-dialog').close();
    if(event.target===document.getElementById('image-dialog'))event.target.close();
  });
  document.addEventListener('play',event=>{if(event.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==event.target)a.pause();});},true);
  document.addEventListener('error',event=>{if(event.target.tagName==='IMG'){event.target.replaceWith(Object.assign(document.createElement('span'),{className:'small muted',textContent:'Preview unavailable'}));}else if(event.target.tagName==='AUDIO')toast('This browser could not play the file. Use Open audio file.');},true);
  document.addEventListener('keydown',event=>{if(event.key==='/'&&!['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)&&!document.getElementById('image-dialog').open){event.preventDefault();document.getElementById('global-query').focus();}});
  window.addEventListener('hashchange',()=>{document.getElementById('image-dialog').close();render();});
  render();
})();
