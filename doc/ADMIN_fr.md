# Guide d'administration

## Lanceur global julia

Un lanceur global est installé dans /usr/local/bin/julia (instance principale uniquement).
Il utilise le dépôt juliaup partagé dans /home/julia/.julia et exécute le binaire Julia
depuis /home/julia/.juliaup.
Le lanceur force aussi HOME=/home/julia pour éviter les erreurs chez les utilisateurs sans
répertoire personnel.
Il change également le répertoire de travail vers /home/julia pour éviter les erreurs
lorsque le répertoire courant n'existe pas pour l'appelant.

Notes :
- Préférez le panneau de configuration du webadmin pour gérer juliaup.
- Il s'agit d'une installation globale de Julia gérée par juliaup. Cela suffit pour les
  autres apps ou services YunoHost qui dépendent de Julia : ils peuvent appeler le
  lanceur global `julia` et s'appuyer sur juliaup pour les versions et environnements.
- Le lanceur est prévu pour une exécution système sans configuration supplémentaire.
- Ce package est mono‑instance (dépôt et lanceur juliaup partagés).

## Lanceur global juliaup

Un lanceur global est installé dans /usr/local/bin/juliaup (instance principale uniquement).
Il s'exécute avec HOME=/home/julia et utilise le dépôt juliaup partagé.

## Actions webadmin

Dans le webadmin YunoHost, utilisez le « Panneau de configuration » de l'app pour accéder
aux actions juliaup (statut, ajout/suppression de versions, version par défaut, mise à jour).

## CLI (optionnel)

Si vous souhaitez tout de même gérer les versions en ligne de commande, utilisez le lanceur global :

- Lister les versions installées : `juliaup status`
- Installer la LTS : `juliaup add lts`
- Installer une version précise : `juliaup add 1.11`
- Définir la version par défaut : `juliaup default 1.11`
- Mettre à jour les versions installées : `juliaup update`
- Mettre à jour juliaup : `juliaup self update`
- Supprimer une version : `juliaup remove 1.10`
