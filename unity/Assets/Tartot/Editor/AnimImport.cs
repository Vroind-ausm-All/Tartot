using UnityEditor;
using UnityEngine;

namespace Tartot.Unity.EditorTools
{
    /// <summary>
    /// Importeinstellungen fuer die Animationsstreifen: Pixel bleiben Pixel.
    /// Ohne das glaettet Unity die Streifen und skaliert sie auf Zweierpotenzen,
    /// dann verrutschen die Einzelbilder.
    /// </summary>
    public sealed class AnimImport : AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if (!assetPath.Replace('\\', '/').Contains("Resources/Tartot/Anim/")) return;
            var importer = (TextureImporter)assetImporter;
            importer.textureType = TextureImporterType.Default;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled = false;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.alphaIsTransparency = true;
        }
    }
}
