/** SKL-NB01 机械裁帧与打包；不重绘、不抠色、不修改原始 Alpha。 */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const sharp = require('sharp');
const root = process.cwd();
const configPath = 'assets/RAW/skills/SKL-NB01/v001/processing_config.json';
const config = JSON.parse(await fs.readFile(configPath, 'utf8'));
const out = path.resolve(root, config.output_dir);
for (const dir of ['frames', 'sheets', 'icons', 'godot', 'review']) await fs.mkdir(path.join(out, dir), {recursive:true});
const manifest = {schema_version:1, batch_id:config.batch_id, version:config.version, status:'art_candidate_not_runtime_integrated', generator:'built-in image_gen', processing:'explicit row cuts; per-row column gutters; fixed hero scale per source; nearest-neighbor; original alpha preserved', frame_count:0, icon_count:0, sources:[], animations:[], icons:[]};
const qa = {alpha_threshold:config.alpha_analysis_threshold, missing_sources:[], empty_frames:[], border_failures:[], source_cut_warnings:[], sources:[], frame_count:0};
const hash = b => crypto.createHash('sha256').update(b).digest('hex');

function bounds(data, width, rect, accept) {
  let x0=Infinity,y0=Infinity,x1=-1,y1=-1,n=0,sx=0;
  for(let y=rect[1];y<rect[1]+rect[3];y++) for(let x=rect[0];x<rect[0]+rect[2];x++) {
    const p=(y*width+x)*4;
    if(accept(data[p],data[p+1],data[p+2],data[p+3])) {x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);n++;sx+=x;}
  }
  return n?{x0,y0,x1,y1,n,cx:sx/n}:null;
}

// 连通区域仅用于分离相邻角色帧，目标区域内的原始 RGBA 不改色、不重画。
function heroComponents(data,width,y0,y1) {
  const labels=new Int32Array(data.length/4);let id=0;const found=[];
  for(let y=y0;y<y1;y++)for(let x=0;x<width;x++) {
    const k=y*width+x;if(labels[k]||data[k*4+3]<128)continue;
    id++;const queue=[k];labels[k]=id;let head=0,x0=x,x1=x,top=y,bottom=y;
    while(head<queue.length){const p=queue[head++],px=p%width,py=Math.floor(p/width);x0=Math.min(x0,px);x1=Math.max(x1,px);top=Math.min(top,py);bottom=Math.max(bottom,py);
      for(const [nx,ny]of [[px-1,py],[px+1,py],[px,py-1],[px,py+1]]){if(nx<0||nx>=width||ny<y0||ny>=y1)continue;const n=ny*width+nx;if(!labels[n]&&data[n*4+3]>=128){labels[n]=id;queue.push(n);}}
    }
    if(queue.length>10000)found.push({id,x0,x1,y0:top,y1:bottom,area:queue.length});
  }
  return {labels,found:found.sort((a,b)=>a.x0-b.x0)};
}

for(const source of config.sources) {
  const sourcePath=path.join(root,config.raw_dir,source.file);
  try {await fs.access(sourcePath);} catch {qa.missing_sources.push(source.file);continue;}
  const original=await fs.readFile(sourcePath);
  const {data,info}=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  if(!source.row_edges || source.row_edges.at(-1)!==info.height) throw new Error(source.file+': review row_edges before processing');
  const srcRecord={asset_id:source.asset_id,file:source.file,sha256:hash(original),size:[info.width,info.height],row_edges:source.row_edges,animations:[]};
  let opaque=0,transparent=0;
  for(let i=3;i<data.length;i+=4) {if(data[i]===0)transparent++;if(data[i]===255)opaque++;}
  if(!transparent) throw new Error(source.file+': source has no true transparency');
  qa.sources.push({file:source.file,true_transparent_pixels:transparent,opaque_pixels:opaque});
  for(const anim of source.animations) {
    const row=anim.row, y0=source.row_edges[row], y1=source.row_edges[row+1];
    const xs=[0];
    for(let cut=1;cut<4;cut++) {
      const expected=Math.round(info.width*cut/4),radius=Math.floor(info.width*0.06);
      let best=expected,score=Infinity;
      for(let x=expected-radius;x<=expected+radius;x++) {
        let n=0;for(let y=y0;y<y1;y++)for(let dx=-3;dx<=3;dx++)if(data[(y*info.width+x+dx)*4+3]>=config.alpha_analysis_threshold)n++;
        const value=n*1000+Math.abs(x-expected);
        if(value<score) {best=x;score=value;}
      }
      xs.push(best);
    }
    xs.push(info.width);
    const components=anim.kind==='hero'?heroComponents(data,info.width,y0,y1):null;
    if(components&&components.found.length!==4)throw new Error(source.file+' row '+row+': expected four isolated hero regions, got '+components.found.length);
    const rects=components?components.found.map(b=>{const x=Math.max(0,b.x0-8),y=Math.max(y0,b.y0-8);return[x,y,Math.min(info.width,b.x1+9)-x,Math.min(y1,b.y1+9)-y];}):Array.from({length:4},(_,i)=>[xs[i],y0,xs[i+1]-xs[i],y1-y0]);
    const bodies=rects.map(rect=>bounds(data,info.width,rect,(r,g,b,a)=>a>128&&r>160&&g>110&&g<=r*1.05&&b<r*0.72));
    const baseline=Math.max(...bodies.filter(Boolean).map(b=>b.y1))+3;
    const name=source.asset_id+'_'+anim.name;
    const record={id:name,skill:source.asset_id,label:anim.label,kind:anim.kind,fps:anim.fps,loop:anim.loop,canvas:anim.canvas,anchor:anim.anchor,attach_point:anim.kind==='hero'?'player_root':anim.anchor_mode==='ground'?'ground':anim.name==='stun_stars'?'above_target_head':'effect_center',godot_offset:[anim.canvas[0]/2-anim.anchor[0],anim.canvas[1]/2-anim.anchor[1]],scale:anim.kind==='hero'?source.body_target_height/source.body_reference_height:anim.scale,notes:anim.notes,frames:[],source_rects:[],source_anchors:[]};
    const frameBuffers=[];
    for(let i=0;i<4;i++) {
      const rect=rects[i], visible=bounds(data,info.width,rect,(r,g,b,a)=>a>=config.alpha_analysis_threshold);
      if(!visible)throw new Error(name+': empty source frame '+i);
      const body=bodies[i];
      const sourceAnchor=anim.kind==='hero'?[Math.round(body?.cx??(rect[0]+rect[2]/2)),baseline]:[Math.round(info.width*(i+0.5)/4),anim.anchor_mode==='ground'?(anim.source_ground_y??y1-18):Math.round((y0+y1)/2)];
      const scale=record.scale,w=Math.round(rect[2]*scale),h=Math.round(rect[3]*scale);
      const left=Math.round(anim.anchor[0]-(sourceAnchor[0]-rect[0])*scale),top=Math.round(anim.anchor[1]-(sourceAnchor[1]-rect[1])*scale);
      if(left<0||top<0||left+w>anim.canvas[0]||top+h>anim.canvas[1])throw new Error(name+': enlarge canvas; fixed scale would crop frame '+i+' '+JSON.stringify({left,top,w,h}));
      let cellInput;
      if(components){const pixels=Buffer.alloc(rect[2]*rect[3]*4),label=components.found[i].id;for(let cy=0;cy<rect[3];cy++)for(let cx=0;cx<rect[2];cx++){const x=rect[0]+cx,y=rect[1]+cy;let belongs=false;for(let dy=-4;dy<=4&&!belongs;dy++)for(let dx=-4;dx<=4;dx++){if(dx*dx+dy*dy>16)continue;const nx=x+dx,ny=y+dy;if(nx>=0&&nx<info.width&&ny>=y0&&ny<y1&&components.labels[ny*info.width+nx]===label){belongs=true;break;}}if(belongs)data.copy(pixels,(cy*rect[2]+cx)*4,(y*info.width+x)*4,(y*info.width+x)*4+4);}cellInput=sharp(pixels,{raw:{width:rect[2],height:rect[3],channels:4}});}
      else cellInput=sharp(original).extract({left:rect[0],top:rect[1],width:rect[2],height:rect[3]});
      const cell=await cellInput.resize(w,h,{kernel:'nearest'}).png().toBuffer();
      const frame=await sharp({create:{width:anim.canvas[0],height:anim.canvas[1],channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:cell,left,top}]).png().toBuffer();
      const filename='frames/'+name+'_right_v001_f'+String(i+1).padStart(2,'0')+'.png';
      await fs.writeFile(path.join(out,filename),frame);
      const raw=await sharp(frame).ensureAlpha().raw().toBuffer();
      let nonempty=0,edge=0;
      for(let y=0;y<anim.canvas[1];y++)for(let x=0;x<anim.canvas[0];x++){const a=raw[(y*anim.canvas[0]+x)*4+3];if(a>=config.alpha_analysis_threshold){nonempty++;if(x<config.transparent_padding||y<config.transparent_padding||x>=anim.canvas[0]-config.transparent_padding||y>=anim.canvas[1]-config.transparent_padding)edge++;}}
      if(!nonempty)qa.empty_frames.push(filename);
      if(edge)qa.border_failures.push({file:filename,visible_pixels_in_padding:edge});
      let sourceEdge=0;
      for(let y=y0;y<y1;y++)for(const x of [rect[0],rect[0]+rect[2]-1])if(data[(y*info.width+x)*4+3]>=64)sourceEdge++;
      if(sourceEdge&&!components)qa.source_cut_warnings.push({file:source.file,animation:name,frame:i+1,source_edge_pixels:sourceEdge});
      record.frames.push(filename);record.source_rects.push(rect);record.source_anchors.push(sourceAnchor);frameBuffers.push(frame);manifest.frame_count++;
    }
    record.sheet='sheets/'+name+'_right_v001_sheet.png';
    await sharp({create:{width:anim.canvas[0]*4,height:anim.canvas[1],channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(frameBuffers.map((input,i)=>({input,left:i*anim.canvas[0],top:0}))).png().toFile(path.join(out,record.sheet));
    manifest.animations.push(record);srcRecord.animations.push({id:name,source_rects:record.source_rects,source_anchors:record.source_anchors});
  }
  manifest.sources.push(srcRecord);
  await sharp(original).flatten({background:'#20232e'}).resize(900,900,{kernel:'nearest'}).png().toFile(path.join(out,'review',source.asset_id+'_dark.png'));
  await sharp(original).flatten({background:'#e6e6e6'}).resize(900,900,{kernel:'nearest'}).png().toFile(path.join(out,'review',source.asset_id+'_light.png'));
}

const iconOriginal=await fs.readFile(path.join(root,config.raw_dir,config.icon_source));
const im=await sharp(iconOriginal).metadata();
for(let i=0;i<6;i++) {
  const x=Math.round((i%3)*im.width/3),x1=Math.round((i%3+1)*im.width/3),y=Math.round(Math.floor(i/3)*im.height/2),y1=Math.round((Math.floor(i/3)+1)*im.height/2);
  const input=sharp(iconOriginal).extract({left:x,top:y,width:x1-x,height:y1-y});
  const file='icons/'+config.sources[i].asset_id+'_icon_v001.png';
  await input.clone().resize(config.icon_size,config.icon_size,{kernel:'nearest'}).png().toFile(path.join(out,file));
  const preview='icons/'+config.sources[i].asset_id+'_icon_preview_v001.png';
  await input.clone().resize(config.icon_preview_size,config.icon_preview_size,{kernel:'nearest'}).png().toFile(path.join(out,preview));
  manifest.icons.push({skill:config.sources[i].asset_id,file,preview,size:[config.icon_size,config.icon_size],source:config.icon_source,source_rect:[x,y,x1-x,y1-y],source_sha256:hash(iconOriginal)});manifest.icon_count++;
}

const allFrames=manifest.animations.flatMap(a=>a.frames);
let tres='[gd_resource type="SpriteFrames" load_steps='+String(allFrames.length+1)+' format=3]\n\n';
allFrames.forEach((f,i)=>{tres+='[ext_resource type="Texture2D" path="res://'+config.output_dir+'/'+f+'" id="'+String(i+1)+'"]\n';});
let frameIndex=0;
tres+='\n[resource]\nanimations = [\n';
tres+=manifest.animations.map(a=>'{\n"frames": ['+a.frames.map(()=>'{"duration": 1.0, "texture": ExtResource("'+String(++frameIndex)+'")}').join(', ')+'],\n"loop": '+a.loop+',\n"name": &"'+a.id+'",\n"speed": '+a.fps+'.0\n}').join(',\n');
tres+='\n]\n';
await fs.writeFile(path.join(out,'godot/SKL-NB01_sprite_frames.tres'),tres);
qa.frame_count=manifest.frame_count;qa.icon_count=manifest.icon_count;qa.passed=!qa.missing_sources.length&&!qa.empty_frames.length&&!qa.border_failures.length&&manifest.frame_count===96&&manifest.icon_count===6;
await fs.writeFile(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
await fs.writeFile(path.join(out,'qa.json'),JSON.stringify(qa,null,2)+'\n');
await fs.copyFile(configPath,path.join(out,'processing_config.json'));
const cards=config.sources.map((s,i)=>'<article><h2><img src="'+manifest.icons[i].preview+'">'+s.label+'</h2><div class="views">'+manifest.animations.filter(a=>a.skill===s.asset_id).map(a=>'<figure><canvas width="160" height="144" data-id="'+a.id+'"></canvas><figcaption>'+a.label+'</figcaption></figure>').join('')+'</div><p>'+s.asset_id+' · 主角动作与特效分组 · 右向</p></article>').join('');
const html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>主角六技能素材预览</title><style>*{box-sizing:border-box}body{margin:0;background:#121722;color:#eef1f6;font:15px system-ui,sans-serif;padding:28px}header{max-width:1440px;margin:auto auto 24px}h1{font-size:28px;margin:0 0 10px}p{color:#aeb8ca}button{padding:8px 14px;border:1px solid #526482;border-radius:8px;background:#25334b;color:inherit;cursor:pointer}main{max-width:1440px;margin:auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(500px,1fr));gap:18px}article{padding:18px;border:1px solid #354057;border-radius:14px;background:#1b2332}h2{display:flex;gap:12px;align-items:center;font-size:20px;margin:0 0 16px}h2 img{width:48px;height:48px;image-rendering:pixelated}.views{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}figure{margin:0;text-align:center}canvas{width:100%;height:auto;image-rendering:pixelated;background:#252e40;border-radius:8px}figcaption{font-size:13px;padding-top:8px;color:#ced7e7}@media(max-width:600px){body{padding:14px}main{grid-template-columns:1fr}.views{grid-template-columns:repeat(2,1fr)}}.light canvas{background:#e4e4e4}</style><header><h1>主角六技能 · 素材预览</h1><p>96 帧 · 24 组动作/特效 · 6 枚图标。候选美术包，尚未接入战斗。展示帧率不替代玩法计时。</p><button id="pause">暂停</button> <button id="bg">切换明暗底</button> <button id="root">显示锚点</button></header><main>'+cards+'</main><script>const animations='+JSON.stringify(manifest.animations)+';let paused=false,showRoot=false,clock=0,last=performance.now();document.querySelector("#pause").onclick=e=>{paused=!paused;e.target.textContent=paused?"继续":"暂停"};document.querySelector("#bg").onclick=()=>document.body.classList.toggle("light");document.querySelector("#root").onclick=()=>showRoot=!showRoot;const views=animations.map(a=>({a,canvas:document.querySelector(\'[data-id="\'+a.id+\'"]\'),images:a.frames.map(f=>{const im=new Image;im.src=f;return im})}));function draw(now){if(!paused)clock+=(now-last)/1000;last=now;for(const {a,canvas,images} of views){const ctx=canvas.getContext("2d");ctx.clearRect(0,0,canvas.width,canvas.height);ctx.imageSmoothingEnabled=false;const length=images.length/a.fps,period=a.loop?length:length+0.65,t=clock%period,index=Math.min(images.length-1,Math.floor(t*a.fps)),im=images[index],zoom=a.canvas[0]>96?1:1.35,ox=(canvas.width-a.canvas[0]*zoom)/2,oy=(canvas.height-a.canvas[1]*zoom)/2;if(im.complete)ctx.drawImage(im,ox,oy,a.canvas[0]*zoom,a.canvas[1]*zoom);if(showRoot){ctx.strokeStyle="#ff5e8a";const x=ox+a.anchor[0]*zoom,y=oy+a.anchor[1]*zoom;ctx.beginPath();ctx.moveTo(x-4,y);ctx.lineTo(x+4,y);ctx.moveTo(x,y-4);ctx.lineTo(x,y+4);ctx.stroke()}}requestAnimationFrame(draw)}requestAnimationFrame(draw)</script></html>';
await fs.writeFile(path.join(out,'preview.html'),html);
console.log(JSON.stringify({output:config.output_dir,frames:manifest.frame_count,animations:manifest.animations.length,icons:manifest.icon_count,qa_passed:qa.passed,border_failures:qa.border_failures,source_cut_warnings:qa.source_cut_warnings},null,2));
if(!qa.passed)process.exitCode=1;
