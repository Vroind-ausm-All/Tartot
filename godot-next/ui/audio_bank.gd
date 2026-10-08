extends RefCounted
class_name AudioBank

const RATE:=22050

static func _wav(seconds:float,fn:Callable,loop:=false)->AudioStreamWAV:
	var samples:=int(RATE*seconds);var bytes:=PackedByteArray();bytes.resize(samples*2)
	for i in samples:
		var t=float(i)/RATE;var v=clampf(float(fn.call(t,i)),-1.0,1.0);bytes.encode_s16(i*2,int(v*32767.0))
	var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=RATE;w.stereo=false;w.data=bytes
	if loop:w.loop_mode=AudioStreamWAV.LOOP_FORWARD;w.loop_begin=0;w.loop_end=samples
	return w

static func click()->AudioStreamWAV:return _wav(.12,func(t,i):return sin(TAU*180.0*t)*exp(-t*18.0)*.5)
static func hit()->AudioStreamWAV:return _wav(.20,func(t,i):return (sin(TAU*95.0*t)*.32+sin(TAU*47.0*t)*.18)*exp(-t*9.0))
static func break_stance()->AudioStreamWAV:return _wav(.35,func(t,i):return (sin(TAU*72.0*t)+sign(sin(TAU*31.0*t))*.35)*exp(-t*7.0)*.32)
static func boss()->AudioStreamWAV:return _wav(.7,func(t,i):return (sin(TAU*110.0*t)+sin(TAU*138.59*t)+sin(TAU*164.81*t))/3.0*minf(1.0,t/.04)*exp(-t*1.4)*.35)
static func burn()->AudioStreamWAV:return _wav(.7,func(t,i):return sin(TAU*(190.0-120.0*t)*t)*exp(-t*2.0)*.28)
static func projector()->AudioStreamWAV:return _wav(1.0,func(t,i):var p=fmod(t,.25);return sin(TAU*55.0*t)*.025+(sin(TAU*130.0*t)*.12*(1.0-p/.012) if p<.012 else 0.0),true)
static func music()->AudioStreamWAV:
	var notes=[261.63,311.13,392.0,311.13,233.08,293.66,349.23,293.66,220.0,261.63,311.13,261.63,196.0,246.94,293.66,246.94]
	return _wav(4.0,func(t,i):var step=int(t/.25)%notes.size();var local=fmod(t,.25);var env=minf(1.0,local/.015)*minf(1.0,(.25-local)/.05);var f=notes[step];return (sin(TAU*f*local)+.25*sin(TAU*f*2.0*local))*env*.11,true)
