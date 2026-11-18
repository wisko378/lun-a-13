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

### Auto-exécute

Onglet Hop → « Se recharger après téléport ». Le script se remet en file via
`queue_on_teleport` (ou `syn.queue_on_teleport`, `queueteleport`) : après un hop
ou un changement de mer, il se relance tout seul, whitelist comprise.

Le loader transmet son URL en deuxième argument (`chunk(ID, URL)`) ; c'est elle
qui est rechargée. Un script collé à la main n'a pas d'URL → le bouton répond
`auto-exec : URL inconnue (passe par le loader)`.

L'état est mémorisé dans `getgenv().RFX_AUTOEXEC`, donc une ré-exécution
ré-arme automatiquement la file.

### Mêlée

Onglet Combat → section **Mêlée** : un bouton par style (Black Leg, Electro,
Fishman Karate, Superhuman, Death Step, Sharkman Karate, Electric Claw, Dragon
Talon, Godhuman, Sanguine Art).

Chaque bouton : détection du Tool dans le sac → équipement direct s'il est déjà
là, sinon **simulation d'interaction PNJ** (tp sur le PNJ, `ProximityPrompt` /
`ClickDetector` déclenchés) puis `CommF_:InvokeServer("Buy<Style>")` (relancé
avec `true` pour les paliers à fragments), puis équipement.
Toggle **Auto équiper la mêlée** : rééquipe le style dès qu'il est dans le sac.

Les remotes ne créent rien : le serveur vérifie le Beli, les fragments et les
prérequis de quête (Godhuman demande les 5 styles précédents).

### Raid

Onglet Combat → section **Raid** : champ chip, **Acheter le chip**
(`RaidsNpc Select <chip>`), **Démarrer le raid** (remote + dialogue du PNJ Raid),
**Auto raid** (farm des `Island 1..5` de `_WorldOrigin.Locations`) et
**Lister les chips** (lecture de `ReplicatedStorage.Raids` : `raids` +
`advancedRaids`). Réservé aux Sea 2 / Sea 3.

Le démarrage est la partie la moins sûre : la remote documentée ne couvre que
l'achat du chip, le lancement passe par le dialogue du PNJ. Statut affiché à
chaque tentative.

### Îles

Onglet TP → section **Îles** : champ de nom + **TP sur l'île** (recherche
partielle dans `_WorldOrigin.Locations`), raccourci **TP usine (Factory)** et
**Lister les îles** pour voir les noms réels de ta mer.

### Boutique, mastery, farm mob, quêtes

Onglet Combat, sous la section Raid :

- **Boutique** — `BuyHaki` pour Buso / Geppo / Soru, et `BuyItem` avec un champ
  libre (Katana, Bisento, Musket…). Le serveur vérifie le Beli, comme toujours.
- **Farm mastery** — champ arme + toggle : équipe l'arme demandée et tape
  l'ennemi le plus proche au rythme `attackRate`, ce qui monte la maîtrise.
- **Farm mob / matériau** — champ île + champ mob : TP sur l'île toutes les 6 s
  (via `_WorldOrigin.Locations`) puis tue le mob nommé. C'est la brique
  « usine / Factory Staff » réutilisable pour n'importe quel matériau.
- **Quêtes** — `CurrentQuest` (diagnostic), `EndQuest` (valider),
  `AbandonQuest` (jeter la quête en cours).

### Liste des îles

Onglet TP → section **Îles** : la liste des îles est lue à l'ouverture
(`workspace._WorldOrigin.Locations`), triée, et chaque nom devient un bouton de
téléportation dans un panneau scrollable. Bouton **Rafraîchir** après un
changement de mer, puisque les îles n'ont pas les mêmes noms d'une mer à
l'autre. Le champ libre et le raccourci **TP usine (Factory)** restent là.

### Priorité fruit

Toggle onglet Farm, actif par défaut. Dès qu'un fruit apparaît dans le rayon de
l'ESP, `grabFruitIfAny()` est appelée au début de chaque itération des fermes
(niveau, boss, mob) : le farm en cours laisse sa cible, tp sur le fruit, ramasse,
auto-store, puis reprend. C'est le comportement « fruit avant tout » des hubs.

### Boss de la mer

Onglet Combat → section **Boss de la mer** : la liste dépend de `game.PlaceId`
(First / Second / Third Sea), un bouton par boss. Un clic remplit
`CONFIG.Combat.bossName` et lance `FarmBoss` (tp + attaque en boucle). Relance
le script après un changement de mer pour avoir la bonne liste.

Noms repris du guide de référence (nov. 2026) : Gorilla King, Chef, The Saw,
Yeti, Warden, Magma General, Fishman Lord, Sky Warlord, Lightning God, Cyborg,
Ice Admiral, Diamond, Jeremy, Don Swan, Smoke Admiral, Awakened Ice Admiral,
Tide Keeper, rip_indra, Darkbeard, Stone, Hydra Leader, Kilo Admiral, Captain
Elephant, Beautiful Pirate, Longma, Cursed Skeleton Boss, Cake Queen, Heaven's
Guardian, Hell's Messenger, Soul Reaper, Cake Prince, Dough King,
rip_indra True Form.

Un boss absent de la zone (invocation, event, dimension) ne se tp pas : le
`farm boss` tourne alors en « introuvable — attente ».

### Webhook
 — tout

Fruits ramassés (nom + joueur), points de stat distribués, niveaux (nouveau
palier atteint), test manuel. Styles d'alerte émis depuis le thread principal
du script, en `pcall`, donc un webhook mort ne casse jamais le farm.

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
