# lun-a-13

Collection de scripts.

## bloxfruits/rfx_v2.lua — RFX v3

Script unique (Luau) pour Blox Fruits : ESP multi-catégories, farm fruits et
coffres, auto-stats, téléportation, server hop et protection client.
Compatible Delta, Solara, Fluxus, Xeno.

### ESP — 6 catégories indépendantes

| Catégorie | Détection | Couleur |
|---|---|---|
| Fruits | nom du fruit (`Dragon`, `Dragon-Dragon`, `… Fruit`) + rareté | par rareté |
| Coffres | `Chest`, `Chest1`, `Chest2`, `Chest3` | gris / jaune / cyan |
| Baies | nom contenant `berry` | rose |
| Fleurs | nom contenant `flower` | violet |
| Dealers / PNJ | nom contenant `dealer` | vert |
| Joueurs | personnages des autres joueurs | orange |

Un seul registre pour toutes les catégories : scan des enfants directs de
`workspace` toutes les 3 s, `ChildAdded` / `ChildRemoved` en temps réel, mise à
jour des labels à ~7 Hz avec seuil de distance (pas de re-render inutile).

### Farm

- **Mode Fruits** : `chercher → TP micro-pas → touch/prompt → store → hop`.
- **Mode Coffres** : même boucle, sans stockage.
- Cible : `Any`, `Legendary+`, `Mythical` ou un fruit précis.
- Auto-store via `CommF_:InvokeServer("StoreFruit", …)`, quatre signatures
  tentées (avec Tool, sans Tool, nom brut, nom + Tool).
- Cooldown par cible après un échec, pour éviter la boucle sur un objet fantôme.
- Hop automatique quand la map est vide, mode solo (serveur le moins peuplé ou
  lien de serveur privé).

### Auto stats

Allocation automatique des points de stat :

```lua
CommF_:InvokeServer("AddPoint", "Melee" | "Defense" | "Sword" | "Gun" | "Demon Fruit", points)
```

Points disponibles lus dans `LocalPlayer.Data.Points.Value`, niveaux lus dans
`LocalPlayer.Data.Stats.<Stat>.Level.Value`. Priorité configurable par toggle,
points par tick réglables, bouton « dépenser tout maintenant ».

### TP / mouvement

Téléportation par micro-pas (taille et délai réglables), raccourcis fruit /
coffre / dealer, WalkSpeed, JumpPower, anti-void.

### Protection

Anti-kick (`__namecall`), spoof `WalkSpeed` / `JumpPower` (`__index`), anti-AFK,
diagnostic des fonctions disponibles dans l'executor.

### Whitelist — l'ID passe par le lien

- `bloxfruits/loader.lua` construit l'URL avec l'ID
  (`…/rfx_v2.lua?id=12020224798`) et le transmet en argument du chunk.
- `rfx_v2.lua` refuse de s'exécuter si l'ID reçu n'est pas dans `WHITELIST`
  **ou** ne correspond pas à `LocalPlayer.UserId`.

```lua
local WHITELIST = {
    [12020224798] = true,
}
```

Un refus affiche `[RFX] accès refusé` et sort avant la moindre interface.

### Utilisation

1. Coller `bloxfruits/loader.lua` dans l'exécuteur, ou charger l'URL avec
   `loadstring` en passant l'ID.
2. Le panneau s'ouvre sur l'onglet Farm. `FARM` dans le header lance / coupe la
   boucle, `T` téléporte au fruit le plus proche.

### Notes

- Les remotes dépendent de Blox Fruits : si `CommF_` disparaît, l'onglet
  Protect affiche `absent` et les modules concernés restent muets.
- L'anti-cheat moteur (Byfron) est géré par l'exécuteur, pas par le script.
  Le script contourne la couche jeu : kick, valeurs lues, distance de
  téléportation, AFK.
- Après téléportation, le script doit être relancé sauf si l'auto-exécution de
  l'exécuteur est activée.
