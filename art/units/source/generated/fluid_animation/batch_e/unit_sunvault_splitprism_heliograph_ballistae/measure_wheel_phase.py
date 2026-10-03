"""Measure observed original spoke phase; no image/motion alteration or acceptance."""
import json
import hashlib
import av
import cv2
import numpy as np
import produce as p

folder=p.SOURCE_DIR/'wheel_assembly_h3_v1'
record=json.loads((folder/'original.json').read_bytes())
assert p.sha(folder/'original_lossless.mkv')==record['sha256']
with av.open(str(folder/'original_lossless.mkv')) as video:
    frames=[np.asarray(f.to_image().convert('RGB')) for f in video.decode(video=0)]
assert len(frames)==124
crop=frames[0][190:582,530:866].astype('int16')
blue=((crop[:,:,2]-crop[:,:,0]>35)&(crop[:,:,2]-crop[:,:,1]>15)).astype('uint8')*255
contours,_=cv2.findContours(blue,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
contour=max(contours,key=cv2.contourArea)
(x,y),(w,h),angle=cv2.fitEllipse(contour)
center=np.array([x+530,y+190]);radii=np.array([w,h])/2
rotation=np.deg2rad(angle)
matrix=np.array([[np.cos(rotation),-np.sin(rotation)],[np.sin(rotation),np.cos(rotation)]])
theta=np.linspace(0,2*np.pi,720,endpoint=False)
profiles=[]
for i,a in enumerate(frames):
    assert hashlib.sha256(a.tobytes()).hexdigest()==record['decoded_rgb_sha256'][i]
    channels=[]
    for radius in [.45,.5,.55,.6,.65,.7]:
        pts=(matrix@(np.vstack((np.cos(theta),np.sin(theta)))*radii[:,None]*radius)).T+center
        samples=cv2.remap(a,pts[:,0].astype('float32').reshape(1,-1),pts[:,1].astype('float32').reshape(1,-1),cv2.INTER_LINEAR).astype('float32')[0]
        channels.append(samples[:,2]-samples[:,0])
    profile=np.mean(channels,axis=0)
    profile=(profile-profile.mean())/(profile.std()+1e-6)
    profiles.append(profile)
phase=[0.0];quality=[]
for before,after in zip(profiles,profiles[1:]):
    scores=[float(np.mean(np.roll(before,k)*after)) for k in range(-30,31)]
    k=int(np.argmax(scores))-30
    phase.append(phase[-1]+k*.5);quality.append(max(scores))
print('Observer ellipse',center.tolist(),radii.tolist(),angle)
print('Observed clockwise-image angle (degrees) every8 source frames:',[(i,round(phase[i],1)) for i in range(0,124,8)])
print('Net degrees',round(phase[-1],1),'phase range',round(min(phase),1),round(max(phase),1),'minimum correlation',round(min(quality),3))
print('An observer only: symmetry/paint and camera interpretation still require personal source review.')
