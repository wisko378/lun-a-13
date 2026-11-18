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

### Combat — farm level et boss

- **Auto farm level** : accepte la quête (`CommF_:InvokeServer("StartQuest", <clé>,
  <niveau>)`), TP sur le mob demandé dans `workspace.Enemies`, frappe, enchaîne.
  Chaîne complète intégrée, **88 paliers de 1 à 2524+** : Sea 1 (Bandit → Galley
  Captain), Sea 2 (Raider → Water Fighter), Sea 3 (Pirate Millionaire → Isle
  Champion). Au-delà du dernier palier, le farm garde le dernier et continue
  jusqu'au `Niveau max` réglé (2600 par défaut, slider 700–3000).
- Le mob est ciblé par nom exact (suffixe `[Lv. x]` ignoré), pas par sous-chaîne :
  `Pirate` ne part pas chasser un `Pirate Millionaire`.
- Les clés de quête changent de mer : le farm suit ton niveau, et le hop garde
  la même place (Sea 1 `2753915549`, Sea 2 `4442272183`, Sea 3 `7449423635`) —
  le passage de mer lui-même reste manuel.
- **Auto farm boss** : nom optionnel (vide = les ennemis les plus costauds,
  seuil `HP minimum` réglable), TP + frappe en boucle.
- **Attaque rapide (no CD)** : boucle d'attaque sans délai de clic,
  `Tool:Activate()` + `ClickButton1` + `CommF_ "Attack"` en secours.
- **Auto équiper une arme** depuis le sac si la main est vide.

### Webhook

Notifications Discord depuis l'onglet Web : fruits ramassés, résumé du farm,
message de test. POST JSON avec `request` / `http_request` / `syn.request` /
`game:HttpPost` selon ce que l'exécuteur expose. L'URL se colle dans l'onglet
Web ; elle est visible par quiconque lit le script.

### TP / mouvement

Téléportation par micro-pas (taille et délai réglables), raccourcis fruit /
coffre / dealer, WalkSpeed, JumpPower, anti-void.

Boutons **Sea 1 / Sea 2 / Sea 3** dans l'onglet TP : chaque mer est une place
Roblox séparée (`2753915549`, `4442272183`, `7449423635`), le bouton téléporte
directement dessus, avec cooldown de 8 s et détection de la mer actuelle.
L'accès reste verrouillé côté serveur : une mer non débloquée te renvoie en
arrière, ce n'est pas le bouton qui décide.

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
