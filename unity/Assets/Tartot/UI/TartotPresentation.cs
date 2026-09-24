using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    [RequireComponent(typeof(UIDocument))]
    public sealed class TartotPresentation:MonoBehaviour
    {
        private VisualElement _root,_safeArea,_enemyArt,_filmGrain,_filmVignette,_filmScratch,_bossCard;
        private Label _enemyName,_enemyHp,_enemyStance,_enemyRule,_playerDark,_overlayTitle,_bossTitle,_bossRule;
        private Button _actButton;
        private AudioSource _sfx,_music,_projector;
        private string _lastEnemy=string.Empty,_lastHp=string.Empty,_lastStance=string.Empty,_lastOverlay=string.Empty;
        private float _bossCardUntil,_buttonUntil,_nextFrame;
        private int _filmFrame;
        private float _safeX=-1,_safeY=-1,_safeW=-1,_safeH=-1;

        private void OnEnable()
        {
            _root=GetComponent<UIDocument>().rootVisualElement;
            _safeArea=_root.Q<VisualElement>("safe-area");
            _enemyArt=_root.Q<VisualElement>("gegner-silhouette");
            _enemyName=_root.Q<Label>("gegner-name");
            _enemyHp=_root.Q<Label>("gegner-hp");
            _enemyStance=_root.Q<Label>("gegner-haltung");
            _enemyRule=_root.Q<Label>("gegner-regel");
            _playerDark=_root.Q<Label>("spieler-dunkel");
            _overlayTitle=_root.Q<Label>("overlay-titel");
            _filmGrain=_root.Q<VisualElement>("film-grain");
            _filmVignette=_root.Q<VisualElement>("film-vignette");
            _filmScratch=_root.Q<VisualElement>("film-scratch");
            _bossCard=_root.Q<VisualElement>("boss-titelkarte");
            _bossTitle=_root.Q<Label>("boss-titel");
            _bossRule=_root.Q<Label>("boss-regel");
            _actButton=_root.Q<Button>("ausfuehren");
            if(_filmGrain!=null)_filmGrain.style.backgroundImage=new StyleBackground(TartotPixelArt.FilmGrain());
            if(_filmVignette!=null)_filmVignette.style.backgroundImage=new StyleBackground(TartotPixelArt.Vignette());
            SetupAudio();
            if(_actButton!=null)_actButton.clicked+=OnActPressed;
            foreach(var name in new[]{"platz-past","platz-present","platz-future"}) _root.Q<VisualElement>(name)?.RegisterCallback<ClickEvent>(_=>Play(TartotAudioBank.CardPlace(),.75f));
            ApplySafeArea(true);
        }

        private void OnDisable(){if(_actButton!=null)_actButton.clicked-=OnActPressed;}
        private void SetupAudio(){_sfx=gameObject.AddComponent<AudioSource>();_sfx.playOnAwake=false;_sfx.volume=.62f;_music=gameObject.AddComponent<AudioSource>();_music.playOnAwake=false;_music.loop=true;_music.volume=.16f;_music.clip=TartotAudioBank.CombatLoop();_music.Play();_projector=gameObject.AddComponent<AudioSource>();_projector.playOnAwake=false;_projector.loop=true;_projector.volume=.055f;_projector.clip=TartotAudioBank.ProjectorLoop();_projector.Play();}
        private void Update(){ApplySafeArea(false);TickTwelveFps();RefreshEnemyArtAndAudio();RefreshOverlayAudio();RefreshDarknessAudio();if(_bossCard!=null&&_bossCard.style.display==DisplayStyle.Flex&&Time.unscaledTime>=_bossCardUntil)_bossCard.style.display=DisplayStyle.None;if(_actButton!=null&&Time.unscaledTime>=_buttonUntil)_actButton.EnableInClassList("knopf--gedrueckt",false);}
        private void TickTwelveFps(){if(Time.unscaledTime<_nextFrame)return;_nextFrame=Time.unscaledTime+1f/12f;_filmFrame++;_enemyArt?.EnableInClassList("enemy__art--bob",_filmFrame%4==1||_filmFrame%4==2);_filmGrain?.EnableInClassList("film-grain--alt",(_filmFrame&1)==1);_filmScratch?.EnableInClassList("film-scratch--alt",_filmFrame%7==0);}

        private void RefreshEnemyArtAndAudio()
        {
            var enemy=_enemyName?.text??string.Empty;
            if(enemy!=_lastEnemy){if(!string.IsNullOrEmpty(enemy)&&enemy!="—"){if(_enemyArt!=null)_enemyArt.style.backgroundImage=new StyleBackground(TartotPixelArt.Enemy(enemy));if(IsBoss(enemy))ShowBossCard(enemy);}_lastEnemy=enemy;}
            var hp=_enemyHp?.text??string.Empty;if(!string.IsNullOrEmpty(_lastHp)&&hp!=_lastHp&&!string.IsNullOrEmpty(hp))Play(TartotAudioBank.Hit(),.8f);_lastHp=hp;
            var stance=_enemyStance?.text??string.Empty;if(!string.IsNullOrEmpty(_lastStance)&&stance.Contains("GEBROCHEN")&&!_lastStance.Contains("GEBROCHEN")){Play(TartotAudioBank.StanceBreak(),1f);Vibrate();}_lastStance=stance;
        }

        private void RefreshOverlayAudio(){var title=_overlayTitle?.text??string.Empty;if(title==_lastOverlay)return;if(title.Contains("DIE WELT"))Play(TartotAudioBank.World(),1f);else if(title.Contains("DU FÄLLST")||title.Contains("RUN ENDET"))Play(TartotAudioBank.FilmBurn(),.9f);_lastOverlay=title;}
        private void RefreshDarknessAudio(){if(_music==null)return;var text=_playerDark?.text??string.Empty;var darkness=0;var lastSpace=text.LastIndexOf(' ');if(lastSpace>=0)int.TryParse(text.Substring(lastSpace+1),out darkness);_music.pitch=1f-Math.Min(.08f,darkness*.0008f);_projector.pitch=1f-Math.Min(.045f,darkness*.00045f);}
        private void ShowBossCard(string enemy){if(_bossCard==null)return;_bossTitle.text=enemy;_bossRule.text=_enemyRule?.text??string.Empty;_bossCard.style.display=DisplayStyle.Flex;_bossCardUntil=Time.unscaledTime+1.65f;Play(TartotAudioBank.BossSting(),1f);Vibrate();}
        private void OnActPressed(){Play(TartotAudioBank.CardPlace(),.9f);if(_actButton!=null)_actButton.EnableInClassList("knopf--gedrueckt",true);_buttonUntil=Time.unscaledTime+.12f;}
        private void Play(AudioClip clip,float volume){if(_sfx!=null&&clip!=null)_sfx.PlayOneShot(clip,volume);}
        private static bool IsBoss(string enemy){var u=enemy.ToUpperInvariant();return u.Contains("·")||u.Contains("WELTENWURM")||u.Contains("DIE WELT");}

        private void ApplySafeArea(bool force)
        {
            if(_safeArea==null||Screen.width<=0||Screen.height<=0)return;
            var safe=Screen.safeArea;
            if(!force&&safe.x==_safeX&&safe.y==_safeY&&safe.width==_safeW&&safe.height==_safeH)return;
            _safeX=safe.x;_safeY=safe.y;_safeW=safe.width;_safeH=safe.height;
            var sx=270f/Screen.width;var sy=480f/Screen.height;
            _safeArea.style.paddingLeft=safe.xMin*sx;_safeArea.style.paddingRight=(Screen.width-safe.xMax)*sx;_safeArea.style.paddingBottom=safe.yMin*sy;_safeArea.style.paddingTop=(Screen.height-safe.yMax)*sy;
        }

        private static void Vibrate()
        {
#if UNITY_ANDROID || UNITY_IOS
            Handheld.Vibrate();
#endif
        }
    }
}
