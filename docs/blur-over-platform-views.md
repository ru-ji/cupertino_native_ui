# Pourquoi le blur ne passe pas sur le switch natif

## 1. Comment on intègre du SwiftUI, et comment Flutter le rend

Chaîne complète, pour `CupertinoNativeSwitch` :

```
Dart  UiKitView(viewType: ".../cupertino_native_toggle")
  ->  NativeToggleFactory.create()                     (FlutterCupertinoPlugin.swift)
  ->  NativeToggleView : NativeHostingView             (UIHostingController<AnyView>)
  ->  AdaptiveToggleView  ==  SwiftUI Toggle == UISwitch
```

Côté moteur, sur iOS, `UiKitView` = **hybrid composition**, toujours. Il n'y a pas
de "virtual display" comme sur Android. Concrètement, par frame, l'embedder
(`FlutterPlatformViews.mm`) construit ceci dans la `FlutterView` :

```
[ surface Flutter principale (CAMetalLayer) ]     <- tout ce qui est peint AVANT la 1re PV
[ ChildClippingView -> UIView du switch ]         <- la vraie UIView SwiftUI
[ FlutterOverlayView #1 (CAMetalLayer) ]          <- le Flutter peint APRES le switch
[ ChildClippingView -> UIView suivante ]
[ FlutterOverlayView #2 ]
...
```

Points qui comptent :

- L'ordre z **respecte l'ordre de peinture Flutter**. Une PV peinte plus tard est
  `bringSubviewToFront`.
- Le Flutter peint *au-dessus* d'une PV ne peut pas aller dans la surface
  principale (elle est dessous) : le moteur alloue une **overlay**, une surface
  Metal séparée, **effacée en transparent** à chaque frame, et n'y peint que le
  contenu qui recouvre la PV.

## 2. La faille

Ton raisonnement — "le texte de l'app bar passe au-dessus, donc ce n'est pas un
problème de couche" — est **juste**, et c'est exactement pour ça que le blur
échoue quand même. Ce n'est pas un problème d'ordre, c'est un problème de
**source d'échantillonnage**.

- Le **texte** est du *paint* : on écrit des pixels dans l'overlay. Une overlay
  vide suffit à écrire dedans. -> visible au-dessus du switch. ✅
- Le **blur** (`BackdropFilter` = `ImageFilter` sur backdrop) est une
  *lecture* : un backdrop filter ne peut lire que **sa propre render target**.
  Sa render target ici, c'est l'overlay — qui vient d'être effacée en
  transparent et qui ne contient ni la surface Flutter principale, ni, à plus
  forte raison, la `UIView` du switch (elle n'est jamais rasterisée dans une
  texture Flutter, elle est composée par le render server d'iOS).
  Donc le filtre floute **du vide**, ne produit rien, et le switch remonte net. ❌

C'est le bug amont `flutter/flutter#48521` (BackdropFilter ne floute pas les
platform views en hybrid composition). Rien à corriger dans notre code : c'est
structurel. Le commentaire dans `FlutterCupertinoPlugin.renderSymbol` dit déjà
la même chose pour les SF Symbols — la raison pour laquelle on rasterise les
icônes au lieu d'en faire des platform views.

**Corollaire :** le teinte/scrim, lui, marche (c'est du paint). D'où le symptôme
typique : sous l'app bar, tout se voile *sauf* les contrôles natifs qui restent
nets sur un fond lavé.

## 3. La seule sortie : un effet natif

Un `UIVisualEffectView` est la seule vue à qui UIKit donne le backdrop du render
server : il échantillonne **toute la hiérarchie composée en dessous de lui**,
surface Flutter *et* UIViews natives. C'est ce que fait déjà
`CupertinoScrollEdgeEffect(native: true)` -> `NativeScrollEdgeEffectView.swift`,
branché dans les deux app bars.

Coût assumé : le rayon est celui du material, pas le nôtre ; `intensity` module
ce qui transparaît du masque, pas la largeur du noyau -> rampe plus plate que le
shader.

## 4. Si `native: true` ne blur toujours pas — ordre de vérification

1. **Le plugin est-il seulement enregistré ?** `NativeScrollEdgeEffectView.swift`
   est encore *untracked*, et l'enregistrement dans `FlutterCupertinoPlugin.swift`
   est non commité, pendant que `example/ios/Podfile` et le `project.pbxproj`
   sont revenus en arrière dans le worktree. Un hot reload ne suffit pas : sans
   rebuild natif complet, le `viewType` n'existe pas et Flutter log
   `PlatformView ... not registered` en n'affichant rien. À écarter en premier.
2. **La vue existe-t-elle et est-elle bien dimensionnée / au-dessus ?**
   `EdgeEffectView.debugPaintRect = true` -> bande rouge = géométrie et z-order
   bons, seul le backdrop manque. Pas de rouge = vue absente, taille nulle, ou
   masque plein. Les `print` DEBUG donnent déjà `intensity` et les `bounds`.
3. **`intensity` reste-t-elle à 0 ?** Dans le `CupertinoSliverAppBar`, elle est
   pilotée par `_titleT.value` : au repos, elle vaut 0 et `blurView.effect = nil`.
   C'est voulu (l'effet système monte depuis zéro), mais ça ressemble à une panne
   si on regarde la page non scrollée.
4. **Contrôle glass iOS 26.** Hypothèse restante si 1-3 sont bons : le `UISwitch`
   d'iOS 26 est un contrôle *liquid glass*, rendu dans sa propre passe, et
   plausiblement exclu du backdrop capturé par un `UIVisualEffectView` frère.
   Test d'une minute sur la page Native Zoo : mettre côte à côte sous le même
   `_blurProbe` un switch et une `CupertinoNativeList` (non-glass). Si la liste
   floute et pas le switch, c'est ça, et la seule réponse est de ne pas laisser
   un switch passer sous la barre (style `hard`, qui est un `ColoredBox` opaque
   et couvre n'importe quoi).

## 5. À noter au passage

`cupertino_app_bar.dart:990` applique un `ImageFiltered` au bloc de titre inline.
Toute platform view qui finirait dans ce sous-arbre (un bouton de barre natif)
ne serait pas filtrée et se comporterait mal — même cause, même famille.
