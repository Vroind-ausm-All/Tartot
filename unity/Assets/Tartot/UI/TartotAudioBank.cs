using System;
using System.Collections.Generic;
using UnityEngine;

namespace Tartot.Unity
{
    internal static class TartotAudioBank
    {
        private const int Rate=22050;
        private static readonly Dictionary<string,AudioClip> Cache=new Dictionary<string,AudioClip>();
        public static AudioClip CardPlace()=>Get("card_place",()=>NoiseHit(.18f,180f,.32f,31));
        public static AudioClip Hit()=>Get("hit",()=>NoiseHit(.24f,105f,.38f,71));
        public static AudioClip StanceBreak()=>Get("stance_break",MakeBreak);
        public static AudioClip BossSting()=>Get("boss_sting",()=>Chord(.72f,new[]{110f,138.59f,164.81f},.22f));
        public static AudioClip World()=>Get("world",()=>Chord(.95f,new[]{130.81f,164.81f,196f,261.63f},.24f));
        public static AudioClip FilmBurn()=>Get("film_burn",MakeBurn);
        public static AudioClip ProjectorLoop()=>Get("projector_loop",MakeProjector);
        public static AudioClip CombatLoop()=>Get("combat_loop",MakeCombatLoop);

        private static AudioClip Get(string key,Func<float[]> factory){if(Cache.TryGetValue(key,out var clip))return clip;var data=factory();clip=AudioClip.Create("Tartot_"+key,data.Length,1,Rate,false);clip.SetData(data,0);Cache[key]=clip;return clip;}
        private static float[] NoiseHit(float seconds,float tone,float gain,int seed){var n=(int)(Rate*seconds);var data=new float[n];var rng=new System.Random(seed);for(var i=0;i<n;i++){var t=i/(float)Rate;var e=Math.Exp(-t*18.0);var noise=rng.NextDouble()*2.0-1.0;data[i]=(float)(gain*Math.Sin(2*Math.PI*tone*t)*Math.Exp(-t*10.0)+.12*noise*e);}return data;}
        private static float[] MakeBreak(){var n=(int)(Rate*.42f);var data=new float[n];var rng=new System.Random(1932);for(var i=0;i<n;i++){var t=i/(float)Rate;var noise=rng.NextDouble()*2-1;var crack=Math.Sign(Math.Sin(2*Math.PI*37*t));data[i]=(float)(.22*noise*Math.Exp(-t*7)+.20*crack*Math.Exp(-t*9)+.22*Math.Sin(2*Math.PI*74*t)*Math.Exp(-t*5));}return data;}
        private static float[] Chord(float seconds,float[] frequencies,float gain){var n=(int)(Rate*seconds);var data=new float[n];for(var i=0;i<n;i++){var t=i/(float)Rate;var e=Math.Min(1.0,t/.03)*Math.Min(1.0,(seconds-t)/.2);double s=0;foreach(var f in frequencies)s+=Math.Sin(2*Math.PI*f*t)+.28*Math.Sin(4*Math.PI*f*t);data[i]=(float)(gain*e*s/frequencies.Length);}return data;}
        private static float[] MakeProjector(){var n=Rate;var data=new float[n];var rng=new System.Random(19);for(var i=0;i<n;i++){var t=i/(float)Rate;var phase=t%.25f;var click=phase<.012f?(1f-phase/.012f):0f;data[i]=(float)(.025*(rng.NextDouble()*2-1)+.025*Math.Sin(2*Math.PI*50*t)+.12*click*Math.Sin(2*Math.PI*120*t));}return data;}
        private static float[] MakeBurn(){var n=(int)(Rate*.8f);var data=new float[n];var rng=new System.Random(88);for(var i=0;i<n;i++){var t=i/(float)Rate;var noise=rng.NextDouble()*2-1;data[i]=(float)(.12*noise*t*t+.2*Math.Sin(2*Math.PI*(180-120*t)*t)*Math.Exp(-t*2));}return data;}
        private static float[] MakeCombatLoop(){const float seconds=8f;var n=(int)(Rate*seconds);var data=new float[n];var melody=new[]{72,75,79,75,70,74,77,74,68,72,75,72,67,71,74,71,72,75,79,82,79,75,72,67,68,72,75,80,79,75,72,67};for(var i=0;i<melody.Length;i++)AddNote(data,i*.25f,.22f,Midi(melody[i]),.095f);var bass=new[]{48,48,43,43,44,44,43,43,48,48,43,43,44,44,43,43};for(var i=0;i<bass.Length;i++){AddNote(data,i*.5f,.38f,Midi(bass[i]),.075f);AddNote(data,i*.5f+.25f,.16f,Midi(bass[i]+7),.045f);}for(var b=0;b<16;b++)AddNote(data,b*.5f,.035f,900,.07f);return data;}
        private static void AddNote(float[] data,float start,float duration,float frequency,float gain){var i0=(int)(start*Rate);var i1=Math.Min(data.Length,(int)((start+duration)*Rate));for(var i=i0;i<i1;i++){var t=(i-i0)/(float)Rate;var e=Math.Min(1.0,t/.01)*Math.Min(1.0,(duration-t)/.045);var wave=Math.Sin(2*Math.PI*frequency*t)+.30*Math.Sin(4*Math.PI*frequency*t)+.12*Math.Sin(6*Math.PI*frequency*t);data[i]+=(float)(gain*e*wave/1.42);}}
        private static float Midi(int note)=>(float)(440.0*Math.Pow(2.0,(note-69)/12.0));
    }
}
