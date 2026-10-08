using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Audio, Musik und optionale Haptik fuer die Unity-Praesentation.
    /// Alle Aufrufe sind semantische Presentation-Cues; Spielregeln bleiben
    /// ausschliesslich im Core.
    /// </summary>
    public sealed class PresentationFeedbackView
    {
        private readonly bool _audioEnabled;
        private readonly bool _hapticsEnabled;
        private readonly VisualElement _root;
        private readonly AudioSource[] _voices;
        private readonly AudioSource _music;
        private readonly AudioSource _bossMusic;
        private readonly Dictionary<string, AudioClip> _clips =
            new Dictionary<string, AudioClip>();

        private int _voiceIndex;
        private int _selectVariant;
        private int _musicToken;
        private bool _musicStarted;
        private bool _bossMusicTarget;

        public PresentationFeedbackView(
            MonoBehaviour host,
            VisualElement root,
            bool audioEnabled,
            bool hapticsEnabled)
        {
            _audioEnabled = audioEnabled;
            _hapticsEnabled = hapticsEnabled;
            _root = root;

            if (!_audioEnabled || host == null)
            {
                _voices = new AudioSource[0];
                return;
            }

            _voices = new AudioSource[8];
            for (var i = 0; i < _voices.Length; i++)
                _voices[i] = CreateSource(host, false, 1f);

            _music = CreateSource(host, true, .12f);
            _bossMusic = CreateSource(host, true, 0f);
        }

        public void RefreshMusic(bool boss)
        {
            if (!_audioEnabled || _music == null || _bossMusic == null) return;
            EnsureMusicStarted();

            if (_bossMusicTarget == boss) return;
            _bossMusicTarget = boss;

            var start = _bossMusic.volume;
            var target = boss ? .085f : 0f;
            var token = ++_musicToken;

            for (var i = 1; i <= 6; i++)
            {
                var step = i;
                var value = start + (target - start) * (step / 6f);
                _root?.schedule.Execute(() =>
                {
                    if (token == _musicToken) _bossMusic.volume = value;
                }).StartingIn(step * 42);
            }
        }

        public void Dispose()
        {
            ++_musicToken;
            foreach (var voice in _voices)
                if (voice != null) { voice.Stop(); UnityEngine.Object.Destroy(voice); }
            if (_music != null) { _music.Stop(); UnityEngine.Object.Destroy(_music); }
            if (_bossMusic != null) { _bossMusic.Stop(); UnityEngine.Object.Destroy(_bossMusic); }
        }

        public void PlayCardSelect()
        {
            var name = (_selectVariant++ & 1) == 0 ? "waehlen_1" : "waehlen_2";
            Play(name, .45f, 1.04f);
        }

        public void PlayCardLand()
        {
            Play("landen", .56f, 1f);
        }

        public void PlayBossIntro()
        {
            Play("auftritt", .72f, 1f);
        }

        public void PlayCascadeStep(int index, bool pattern)
        {
            var pitch = (float)Math.Pow(2.0, Math.Min(index, 10) / 12.0);
            Play(pattern ? "mult" : "faktor", pattern ? .43f : .34f, pitch);
        }

        public void PlayFateHit(bool strong)
        {
            Play("gegner_getroffen", strong ? .82f : .62f, strong ? .94f : 1f);
            if (strong) Haptic();
        }

        public void PlayPlayerHit()
        {
            Play("spieler_getroffen", .62f, 1f);
        }

        public void PlayStanceBreak()
        {
            Play("glas", .78f, .96f);
            Haptic();
        }

        public void PlaySealBreak()
        {
            Play("phase", .82f, 1f);
            Haptic();
        }

        public void PlayTowerCollapse()
        {
            Play("angriff_blitz", .82f, .95f);
            Haptic();
        }

        public void PlayWorld()
        {
            Play("schimmer", .74f, 1.03f);
        }

        public void PlayJudgment(bool victory)
        {
            Play(victory ? "sieg" : "toedlich", victory ? .84f : .78f, 1f);
            Haptic();
        }

        private void EnsureMusicStarted()
        {
            if (_musicStarted) return;

            var baseClip = Clip("musik_walzer");
            var bossClip = Clip("musik_walzer_boss");
            if (baseClip == null) return;

            _music.clip = baseClip;
            _music.loop = true;
            _music.volume = .12f;
            _music.Play();

            if (bossClip != null)
            {
                _bossMusic.clip = bossClip;
                _bossMusic.loop = true;
                _bossMusic.volume = 0f;
                _bossMusic.Play();
            }

            _musicStarted = true;
        }

        private void Play(string name, float volume, float pitch)
        {
            if (!_audioEnabled || _voices == null || _voices.Length == 0) return;
            var clip = Clip(name);
            if (clip == null) return;

            var source = _voices[_voiceIndex];
            _voiceIndex = (_voiceIndex + 1) % _voices.Length;
            source.pitch = pitch;
            source.PlayOneShot(clip, volume);
        }

        private AudioClip Clip(string name)
        {
            if (_clips.TryGetValue(name, out var cached)) return cached;
            var clip = Resources.Load<AudioClip>("Tartot/Audio/" + name);
            _clips[name] = clip;
            return clip;
        }

        private static AudioSource CreateSource(MonoBehaviour host, bool loop, float volume)
        {
            var source = host.gameObject.AddComponent<AudioSource>();
            source.playOnAwake = false;
            source.loop = loop;
            source.spatialBlend = 0f;
            source.volume = volume;
            return source;
        }

        private void Haptic()
        {
#if UNITY_ANDROID || UNITY_IOS
            if (_hapticsEnabled) Handheld.Vibrate();
#endif
        }
    }
}
