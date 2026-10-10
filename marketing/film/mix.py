import numpy as np, subprocess, scipy.signal as ss, scipy.io.wavfile as wf, sys
SR=48000; A='/tmp/claude-0/-home-claude-lifewall/18adaa4e-f91d-5be0-acc0-84647a0e12f1/scratchpad/audio/'
DUR=116.5
def load(f, ss_=0, dur=None, ch=2):
    cmd=['ffmpeg','-v','error','-ss',str(ss_)]+(['-t',str(dur)] if dur else [])+['-i',A+f,'-ac',str(ch),'-ar',str(SR),'-f','f32le','-']
    x=np.frombuffer(subprocess.run(cmd,capture_output=True).stdout,dtype=np.float32)
    return x.reshape(-1,ch).copy()
out=np.zeros((int(DUR*SR),2),np.float32)
def place(x,t,g=1.0):
    i=int(t*SR); n=min(len(x),len(out)-i)
    if n>0: out[i:i+n]+=x[:n]*g
def fade(x,fi=0.0,fo=0.0):
    n=len(x)
    if fi>0: k=int(fi*SR); x[:k]*=np.linspace(0,1,k)[:,None]
    if fo>0: k=int(fo*SR); x[n-k:]*=np.linspace(1,0,k)[:,None]
    return x
db=lambda d:10**(d/20)

# 音乐
m=load('lw-music.mp3'); m=m[:len(out)]
env=np.ones(len(m)); a,b=int(110*SR),int(116*SR); env[a:b]=np.linspace(1,0,b-a)**1.5; env[b:]=0
place(m*env[:,None],0,db(0))

# 人声街景（多语言）0–19.69
amb=load('lw-amb.mp3',30,19.75)
e=np.ones(len(amb)); t=np.arange(len(amb))/SR
e*= np.clip(t/2.5,0,1)*(0.55+0.45*np.clip((t-4)/15,0,1))
e[int(19.69*SR):]=0; k=int(0.03*SR); i=int(19.66*SR); e[i:i+k]*=np.linspace(1,0,k)
place(amb*e[:,None],0,db(-15))

# 阿姆斯特朗（无线电质感）
arm=load('lw-armstrong.wav',15.0,9.0)
bb,aa=ss.butter(4,[280,3400],btype='band',fs=SR); arm=ss.lfilter(bb,aa,arm,axis=0).astype(np.float32)
place(fade(arm,0.4,0.8),0.6,db(-4))

# 肯尼迪
moon=load('lw-moon.mp3',4.3,9.4)
place(fade(moon,0.05,0.3),10.0,db(-3))

# 翻页声
fl=load('lw-flip.mp3')
long_=fade(fl[int(0.6*SR):int(1.75*SR)].copy(),0.01,0.15); short=fade(fl[int(1.18*SR):int(1.44*SR)].copy(),0.005,0.08)
F=[];t=2.3
while t<19.42:
    F.append(round(t,3)); r=max(0,1-t/19.62); t+=0.052+1.9*r**1.85
rng=np.random.default_rng(7)
for i,t in enumerate(F):
    gap=(F[i+1] if i+1<len(F) else 19.69)-t
    src=long_ if gap>0.35 else short
    rate=1+rng.uniform(-0.06,0.08)+(0.12 if gap<0.12 else 0)
    n=int(len(src)/rate); y=np.stack([np.interp(np.linspace(0,len(src)-1,n),np.arange(len(src)),src[:,c]) for c in range(2)],1).astype(np.float32)
    g=db(2 if gap>0.35 else -1)*rng.uniform(0.75,1.0)
    pan=rng.uniform(-0.25,0.25); y[:,0]*=1-pan; y[:,1]*=1+pan
    place(y,t-0.04,g)

# 界面音效
def thunk(f0=72,dur=0.32,noise=0.5,seed=1):
    n=int(dur*SR); tt=np.arange(n)/SR
    body=np.sin(2*np.pi*f0*tt*(1+0.6*np.exp(-tt*30)))*np.exp(-tt*16)
    r=np.random.default_rng(seed).standard_normal(n)*np.exp(-tt*90)
    bb,aa=ss.butter(2,2500,fs=SR); r=ss.lfilter(bb,aa,r)
    y=(body+noise*r); y/=np.abs(y).max(); return np.stack([y,y],1).astype(np.float32)
place(thunk(),53.57,db(-9)); place(thunk(),65.29,db(-9))
place(thunk(58,0.45,0.9,3),78.74,db(-7))
place(thunk(90,0.22,0.4,5),92.65,db(-13))

# 收尾：限幅
peak=np.abs(out).max(); print('peak',peak)
out=np.tanh(out*1.0/max(1,peak*0.9)*0.98)
wf.write('mix.wav',SR,(out*32767*0.95).astype(np.int16))
print('flips',len(F))
