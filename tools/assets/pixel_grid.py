"""工具化原生像素转换：单次面积采样到目标整数网格，再限色与硬alpha；不输出放大伪像素图。"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image


def quantize(image, palette, opaque=False, alpha_threshold=0.5):
    """分行限色避免大背景分配巨型距离矩阵；输出没有插值色和半透明边。"""
    a=np.array(image.convert('RGBA'))
    colors=np.array([tuple(bytes.fromhex(c.lstrip('#'))) for c in palette],dtype=np.int32)
    for y in range(0,a.shape[0],32):
        rgb=a[y:y+32,:,:3].astype(np.int32)
        distance=((rgb[:,:,None,:]-colors[None,None,:,:])**2).sum(axis=3)
        a[y:y+32,:,:3]=colors[distance.argmin(axis=2)]
    a[:,:,3]=255 if opaque else (a[:,:,3]>=round(alpha_threshold*255)).astype(np.uint8)*255
    a[a[:,:,3]==0]=0
    return Image.fromarray(a)


def convert(source, canvas, palette, *, anchor='bottom', alpha_cutoff=224, opaque=False, visible_size=None, fit_size=None):
    """源切片直接采样到最终有效像素网格；等比拟合一次，留白补齐画布，不反复缩放。"""
    source=source.convert('RGBA')
    a=np.array(source)
    if not opaque:
        a[a[:,:,3]<alpha_cutoff]=0
    clipped=Image.fromarray(a)
    bbox=(0,0,source.width,source.height) if opaque else clipped.getbbox()
    if bbox is None:
        raise ValueError('source has no visible pixels')
    region=clipped.crop(bbox)
    if visible_size:
        target=tuple(visible_size)
    else:
        bounds=fit_size or canvas
        ratio=min(bounds[0]/region.width,bounds[1]/region.height)
        if ratio>1:
            raise ValueError('Native assets may not be enlarged from a smaller source')
        target=(max(1,round(region.width*ratio)),max(1,round(region.height*ratio)))
    if opaque:
        sampled=region.resize(target,Image.Resampling.BOX)
    else:
        # 预乘alpha后面积采样，透明背景不会把边缘平均成黑边。
        arr=np.array(region).astype(np.float32)/255.0
        alpha=Image.fromarray(arr[:,:,3]).resize(target,Image.Resampling.BOX)
        aa=np.array(alpha)
        rgb=[]
        for channel in range(3):
            premult=Image.fromarray(arr[:,:,channel]*arr[:,:,3]).resize(target,Image.Resampling.BOX)
            rgb.append(np.array(premult)/np.maximum(aa,1e-6))
        sampled=Image.fromarray(np.clip(np.dstack(rgb+[aa])*255,0,255).astype(np.uint8))
    native=quantize(sampled,palette,opaque)
    result=Image.new('RGBA',tuple(canvas))
    offset=((canvas[0]-native.width)//2,0 if anchor=='top' else canvas[1]-native.height)
    result.alpha_composite(native,offset)
    return result,{'source_pixels':list(source.size),'source_crop':list(bbox),'sampled_pixels':list(target),
                   'canvas_pixels':list(canvas),'resampling_passes':1,'sampling':'alpha_weighted_area_then_palette',
                   'runtime_scale':[1,1],'palette_limit':len(palette),'anchor':anchor}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--canvas',nargs=2,type=int,required=True,metavar=('W','H'))
    parser.add_argument('--spec',type=Path,required=True,help='JSON containing palette')
    parser.add_argument('--anchor',choices=['top','bottom'],default='bottom')
    parser.add_argument('--opaque',action='store_true')
    args=parser.parse_args()
    spec=json.loads(args.spec.read_text(encoding='utf8'))
    im,report=convert(Image.open(args.input),args.canvas,spec['palette'],anchor=args.anchor,opaque=args.opaque,
                      alpha_cutoff=spec.get('alpha_cutoff',224))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    im.save(args.output)
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__': main()
