using System;
using System.Collections.Generic;
using UnityEngine;

namespace Tartot.Unity
{
    internal static class TartotPixelArt
    {
        private static readonly Dictionary<string, Texture2D> Cache = new Dictionary<string, Texture2D>();
        private static readonly Color32 Clear = new Color32(0,0,0,0);
        private static readonly Color32 Ink = Hex("1A1412");
        private static readonly Color32 Paper = Hex("EFE3C8");
        private static readonly Color32 Sepia1 = Hex("C9B48E");
        private static readonly Color32 Sepia2 = Hex("8F7A5A");
        private static readonly Color32 Sepia3 = Hex("4E4032");
        private static readonly Color32 Gold = Hex("E3A83B");
        private static readonly Color32 Red = Hex("B3262B");
        private static readonly Color32 Indigo = Hex("3B4A8C");
        private static readonly Color32 Black = Hex("0D0A09");

        public static Texture2D SuitIcon(string key) => Get("suit:"+key, ()=>MakeSuit(key));
        public static Texture2D Enemy(string displayName) => Get("enemy:"+displayName, ()=>MakeEnemy(displayName));
        public static Texture2D Scene(string key) => Get("scene:"+key, ()=>MakeScene(key));
        public static Texture2D FilmGrain() => Get("film:grain", MakeFilmGrain);
        public static Texture2D Vignette() => Get("film:vignette", MakeVignette);

        private static Texture2D Get(string key, Func<Texture2D> factory)
        {
            if (!Cache.TryGetValue(key,out var texture))
            {
                texture=factory();
                texture.name="Tartot_"+key.Replace(':','_');
                Cache[key]=texture;
            }
            return texture;
        }

        private static Texture2D MakeSuit(string key)
        {
            var c=new Canvas(16,16);
            switch(key)
            {
                case "swords": c.Line(4,2,12,14,Ink,2); c.Line(12,2,4,14,Ink,2); c.Line(2,4,6,4,Ink,2); c.Line(10,4,14,4,Ink,2); break;
                case "wands": c.Line(8,2,8,14,Ink,2); c.Line(3,8,13,8,Gold); c.Line(5,5,11,11,Gold); c.Line(11,5,5,11,Gold); break;
                case "cups": c.Rect(4,3,11,7,Paper); c.Line(4,7,7,11,Ink,2); c.Line(11,7,8,11,Ink,2); c.Line(8,10,8,14,Ink,2); c.Line(5,14,11,14,Ink,2); break;
                case "pentacles": c.Circle(8,8,6,Ink,false); c.Line(8,2,11,13,Ink); c.Line(11,13,3,6,Ink); c.Line(3,6,13,6,Ink); c.Line(13,6,5,13,Ink); c.Line(5,13,8,2,Ink); break;
                case "moon": c.Circle(8,8,6,Indigo,true); c.Circle(11,5,5,Clear,true); c.Circle(5,8,1,Paper,true); break;
                default: c.Star(8,8,6,3,Gold); break;
            }
            return c.Texture();
        }

        private static Texture2D MakeEnemy(string name)
        {
            var upper=(name??string.Empty).ToUpperInvariant();
            var c=new Canvas(80,96);
            if(upper.Contains("TURM")) DrawTower(c);
            else if(upper.Contains("MOND")) DrawMoon(c);
            else if(upper.Contains("TOD")) DrawDeath(c);
            else if(upper.Contains("RAD")) DrawWheel(c);
            else if(upper.Contains("TEUFEL")) DrawDevil(c);
            else if(upper.Contains("GEHÄNG")) DrawHanged(c);
            else if(upper.Contains("WELT")) DrawWorld(c);
            else if(upper.Contains("MÜNZE")&&upper.Contains("ZÄHN")) DrawCoin(c);
            else if(upper.Contains("HENKER")) DrawHangman(c);
            else DrawGeneric(c,upper.GetHashCode());
            return c.Texture();
        }

        private static void DrawEyes(Canvas c,int x1,int x2,int y,Color32 color){ c.Circle(x1,y,4,color,true); c.Rect(x1,y-4,x1+4,y,Paper); c.Circle(x2,y,4,color,true); c.Rect(x2,y-4,x2+4,y,Paper); }
        private static void DrawGrin(Canvas c,int x,int y,int w){ c.Rect(x,y,x+w,y+8,Ink); for(var i=x+2;i<x+w-1;i+=5)c.Rect(i,y+1,i+2,y+3,Paper); for(var i=x+3;i<x+w-1;i+=5)c.Rect(i,y+5,i+2,y+7,Paper); }
        private static void Glove(Canvas c,int x,int y){ c.Circle(x,y,4,Paper,true); c.Line(x,y,x-3,y-5,Ink); c.Line(x,y,x,y-6,Ink); c.Line(x,y,x+3,y-5,Ink); }

        private static void DrawGeneric(Canvas c,int seed){ var accent=(seed&1)==0?Sepia1:Sepia2; c.Circle(40,36,21,accent,true); c.Circle(40,36,21,Ink,false); DrawEyes(c,32,48,31,Ink); DrawGrin(c,28,43,25); c.Line(28,55,14,75,Ink,3); c.Line(52,55,66,75,Ink,3); Glove(c,12,78); Glove(c,68,78); c.Line(35,56,31,90,Ink,3); c.Line(45,56,49,90,Ink,3); }
        private static void DrawCoin(Canvas c){ c.Circle(40,44,24,Gold,true); c.Circle(40,44,24,Ink,false); DrawEyes(c,32,48,36,Ink); DrawGrin(c,28,49,25); c.Rect(29,13,51,22,Ink); c.Rect(23,21,57,25,Ink); c.Line(17,46,7,38,Ink,3); c.Line(63,46,73,38,Ink,3); Glove(c,6,37); Glove(c,74,37); }
        private static void DrawHangman(Canvas c){ c.Line(40,0,40,20,Sepia2,3); c.Circle(40,31,15,Paper,true); c.Circle(40,31,15,Ink,false); DrawEyes(c,34,46,27,Ink); DrawGrin(c,31,36,19); c.Line(40,45,40,74,Ink,3); c.Line(40,53,20,66,Ink,3); c.Line(40,53,60,66,Ink,3); Glove(c,18,68); Glove(c,62,68); c.Line(40,74,28,93,Ink,3); c.Line(40,74,52,93,Ink,3); c.Circle(66,62,12,Sepia2,false); }
        private static void DrawTower(Canvas c){ c.Rect(20,24,60,93,Sepia1); c.Rect(20,24,60,93,Ink,false,2); for(var x=20;x<=52;x+=12)c.Rect(x,14,x+8,27,Sepia1); DrawEyes(c,31,49,42,Ink); DrawGrin(c,28,57,25); c.Line(40,24,34,48,Red,2); c.Line(34,48,45,68,Red,2); c.Line(45,68,37,88,Red,2); c.Line(20,55,8,48,Ink,3); c.Line(60,55,72,48,Ink,3); Glove(c,7,47); Glove(c,73,47); c.Line(65,4,57,14,Gold,2); c.Line(57,14,64,16,Gold,2); c.Line(64,16,55,27,Gold,2); }
        private static void DrawMoon(Canvas c){ c.Circle(36,43,31,Indigo,true); c.Circle(36,43,31,Ink,false); c.Circle(54,28,28,Black,true); c.Circle(22,39,4,Paper,true); DrawGrin(c,17,49,27); c.Line(22,70,12,82,Ink,3); c.Line(48,70,62,82,Ink,3); Glove(c,10,84); Glove(c,64,84); c.Star(66,15,5,2,Gold); c.Star(10,18,4,2,Gold); }
        private static void DrawDeath(Canvas c){ c.Circle(40,30,17,Paper,true); c.Circle(40,30,17,Ink,false); DrawEyes(c,33,47,26,Ink); DrawGrin(c,31,36,19); c.Rect(29,8,51,20,Ink); c.Rect(23,18,57,22,Ink); c.Rect(25,47,55,93,Ink); c.Rect(33,48,47,55,Red); c.Line(63,24,64,93,Sepia1,2); c.Line(64,24,76,18,Paper,2); Glove(c,58,58); }
        private static void DrawWheel(Canvas c){ c.Circle(40,45,32,Gold,true); c.Circle(40,45,32,Ink,false); c.Circle(40,45,19,Sepia1,true); c.Circle(40,45,19,Ink,false); for(var i=0;i<8;i++){ var a=i*Math.PI/4.0; c.Line(40,45,40+(int)(Math.Cos(a)*30),45+(int)(Math.Sin(a)*30),Ink);} DrawEyes(c,34,46,41,Ink); DrawGrin(c,31,49,19); }
        private static void DrawDevil(Canvas c){ c.Circle(40,35,21,Red,true); c.Circle(40,35,21,Ink,false); c.Line(27,20,18,6,Red,3); c.Line(53,20,62,6,Red,3); DrawEyes(c,33,47,31,Paper); DrawGrin(c,29,43,23); c.Rect(28,56,52,93,Ink); c.Rect(57,58,76,79,Paper); c.Rect(60,63,73,64,Sepia3); c.Rect(60,68,72,69,Sepia3); Glove(c,55,72); }
        private static void DrawHanged(Canvas c){ c.Line(40,0,40,17,Sepia1,3); c.Circle(40,27,14,Paper,true); c.Circle(40,27,14,Ink,false); DrawEyes(c,34,46,24,Ink); DrawGrin(c,31,32,19); c.Line(40,41,40,76,Ink,3); c.Line(40,50,18,63,Ink,3); c.Line(40,50,62,63,Ink,3); Glove(c,16,65); Glove(c,64,65); c.Line(40,76,25,94,Ink,3); c.Line(40,76,55,94,Ink,3); }
        private static void DrawWorld(Canvas c){ c.Circle(40,42,34,Gold,false); c.Circle(40,42,27,Red,false); c.Circle(40,42,15,Paper,true); c.Circle(40,42,15,Ink,false); DrawEyes(c,34,46,38,Ink); DrawGrin(c,32,47,17); Glove(c,17,82); Glove(c,63,82); }

        private static Texture2D MakeScene(string key)
        {
            var c=new Canvas(160,90); c.Fill(Black); c.Rect(2,2,157,87,Sepia2,false,2); c.Circle(132,18,13,Sepia1,true); c.Line(8,72,152,72,Sepia3,2);
            var k=(key??string.Empty).ToLowerInvariant();
            if(k=="grab"){ c.Rect(54,38,94,72,Sepia1); c.Circle(74,38,20,Sepia1,true); c.Line(74,25,74,55,Ink,2); c.Line(63,38,85,38,Ink,2); }
            else if(k=="kartenspieler"){ c.Circle(73,37,18,Paper,true); c.Circle(73,37,18,Ink,false); DrawEyes(c,66,80,33,Ink); c.Rect(52,55,94,72,Ink); c.Rect(30,46,47,69,Paper); c.Rect(101,44,118,67,Paper); }
            else if(k.Contains("tinte")||k.Contains("blatt")||k.Contains("schreiber")){ c.Rect(51,44,99,71,Sepia2); c.Line(73,15,80,46,k.Contains("schwarz")?Red:Paper,3); c.Circle(80,20,4,k.Contains("schwarz")?Red:Gold,true); }
            else if(k=="spiegel"||k=="waage"||k=="uhrmacher"){ c.Circle(74,44,25,Gold,false); c.Circle(74,44,19,Sepia1,false); c.Star(74,44,11,5,Ink); }
            else if(k=="zirkus"||k=="kinder"){ c.Triangle(24,70,55,24,86,70,Red); c.Triangle(73,70,105,24,137,70,Gold); }
            else { c.Circle(72,43,19,Sepia1,true); c.Circle(72,43,19,Ink,false); DrawEyes(c,65,79,39,Ink); DrawGrin(c,62,49,21); }
            var hash=Math.Abs((key??"").GetHashCode()); for(var i=0;i<5;i++){ var x=8+(hash+i*31)%144; c.Line(x,5,x,85,new Color32(Paper.r,Paper.g,Paper.b,60)); }
            return c.Texture();
        }

        private static Texture2D MakeFilmGrain(){ var c=new Canvas(64,64); var rng=new System.Random(1932); for(var y=0;y<64;y++)for(var x=0;x<64;x++){ var r=rng.Next(1000); if(r<120)c.Set(x,y,new Color32(Paper.r,Paper.g,Paper.b,24)); else if(r<220)c.Set(x,y,new Color32(Ink.r,Ink.g,Ink.b,32)); else if(r<230)c.Set(x,y,new Color32(Red.r,Red.g,Red.b,18)); } return c.Texture(TextureWrapMode.Repeat); }
        private static Texture2D MakeVignette(){ var c=new Canvas(64,64); for(var y=0;y<64;y++)for(var x=0;x<64;x++){ var dx=(x-31.5)/31.5; var dy=(y-31.5)/31.5; var d=Math.Sqrt(dx*dx+dy*dy); var a=(byte)Math.Max(0,Math.Min(180,(d-.45)*320)); c.Set(x,y,new Color32(13,10,9,a)); } return c.Texture(); }
        private static Color32 Hex(string hex)=>new Color32(Convert.ToByte(hex.Substring(0,2),16),Convert.ToByte(hex.Substring(2,2),16),Convert.ToByte(hex.Substring(4,2),16),255);

        private sealed class Canvas
        {
            private readonly int _w,_h; private readonly Color32[] _p;
            public Canvas(int w,int h){_w=w;_h=h;_p=new Color32[w*h];for(var i=0;i<_p.Length;i++)_p[i]=Clear;}
            public void Fill(Color32 color){for(var i=0;i<_p.Length;i++)_p[i]=color;}
            public void Set(int x,int y,Color32 color){if(x>=0&&y>=0&&x<_w&&y<_h)_p[y*_w+x]=color;}
            public void Rect(int x0,int y0,int x1,int y1,Color32 color,bool fill=true,int width=1){if(fill){for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)Set(x,y,color);return;}for(var i=0;i<width;i++){Line(x0+i,y0+i,x1-i,y0+i,color);Line(x0+i,y1-i,x1-i,y1-i,color);Line(x0+i,y0+i,x0+i,y1-i,color);Line(x1-i,y0+i,x1-i,y1-i,color);}}
            public void Line(int x0,int y0,int x1,int y1,Color32 color,int width=1){var dx=Math.Abs(x1-x0);var sx=x0<x1?1:-1;var dy=-Math.Abs(y1-y0);var sy=y0<y1?1:-1;var err=dx+dy;while(true){for(var ox=-width/2;ox<=width/2;ox++)for(var oy=-width/2;oy<=width/2;oy++)Set(x0+ox,y0+oy,color);if(x0==x1&&y0==y1)break;var e2=2*err;if(e2>=dy){err+=dy;x0+=sx;}if(e2<=dx){err+=dx;y0+=sy;}}}
            public void Circle(int cx,int cy,int radius,Color32 color,bool fill){for(var y=-radius;y<=radius;y++)for(var x=-radius;x<=radius;x++){var d=x*x+y*y;if(fill?d<=radius*radius:d<=radius*radius&&d>=(radius-1)*(radius-1))Set(cx+x,cy+y,color);}}
            public void Star(int cx,int cy,int outer,int inner,Color32 color){var pts=new int[20];for(var i=0;i<10;i++){var a=-Math.PI/2+i*Math.PI/5;var r=i%2==0?outer:inner;pts[i*2]=cx+(int)Math.Round(Math.Cos(a)*r);pts[i*2+1]=cy+(int)Math.Round(Math.Sin(a)*r);}for(var i=0;i<10;i++)Line(cx,cy,pts[i*2],pts[i*2+1],color,2);}
            public void Triangle(int x1,int y1,int x2,int y2,int x3,int y3,Color32 color){for(var y=Math.Min(y1,Math.Min(y2,y3));y<=Math.Max(y1,Math.Max(y2,y3));y++)for(var x=Math.Min(x1,Math.Min(x2,x3));x<=Math.Max(x1,Math.Max(x2,x3));x++){var d1=Sign(x,y,x1,y1,x2,y2);var d2=Sign(x,y,x2,y2,x3,y3);var d3=Sign(x,y,x3,y3,x1,y1);var neg=d1<0||d2<0||d3<0;var pos=d1>0||d2>0||d3>0;if(!(neg&&pos))Set(x,y,color);}}
            private static int Sign(int px,int py,int ax,int ay,int bx,int by)=>(px-bx)*(ay-by)-(ax-bx)*(py-by);
            public Texture2D Texture(TextureWrapMode wrap=TextureWrapMode.Clamp){var t=new Texture2D(_w,_h,TextureFormat.RGBA32,false);t.filterMode=FilterMode.Point;t.wrapMode=wrap;t.SetPixels32(_p);t.Apply(false,false);return t;}
        }
    }
}
