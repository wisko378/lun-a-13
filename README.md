# lun-a-13

Collection de scripts.

## bloxfruits/rfx_v2.lua

Script unique (Luau) pour Blox Fruits : radar de fruits, farm automatique,
téléportation, server hop et couche de protection client. Compatible Delta,
Solara, Fluxus, Xeno.

### Ce qu'il fait

- **Farm FRUIT** : boucle `chercher → TP micro-pas → pickup → store → hop`.
  Bouton principal en haut du panneau et dans le header.
- **Radar** : ESP des fruits au sol (`Highlight` + facteur de distance),
  coloré par rareté.
- **TP** : téléportation par micro-pas, taille du pas et délai réglables.
- **Store** : stockage automatique des fruits du sac via
  `ReplicatedStorage.Remotes.CommF_` (`StoreFruit`), avec plusieurs
  signatures tentées en fallback.
- **Hop** : sélection de serveur par population, mode solo (serveur le moins
  peuplé ou lien de serveur privé), auto-hop quand la map est vide.
- **Bypass** : anti-kick (`__namecall`), spoof `WalkSpeed` / `JumpPower`
  (`__index`), anti-AFK, anti-void, diagnostic des fonctions de l'executor.

### Utilisation

1. Copier `bloxfruits/rfx_v2.lua` dans l'éditeur de l'executor, ou l'héberger
   et le charger avec `loadstring(game:HttpGet("<url>"))()`.
2. Exécuter en jeu. Le panneau s'ouvre sur l'onglet Farm.
3. `FARM` dans le header lance / coupe la boucle, `T` téléporte au fruit le plus
   proche.

### Notes

- L'auto-store dépend de `CommF_`. Si le remote n'existe pas, l'onglet Bypass
  affiche `absent` et le stockage ne tente rien.
- Le vrai anti-cheat moteur (Byfron) est géré par l'executor, pas par le script.
  Ce que le script contourne, c'est la couche jeu : kick, valeurs lues, distance
  de téléportation, AFK.
- Après une téléportation, le script doit être relancé sauf si l'auto-exécution
  de l'executor est activée.
