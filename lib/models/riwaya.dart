/// Riwaya (transmission) du texte coranique. Hafs (6236 versets) et Warsh
/// (6214 versets, découpage natif différent) ont chacune leur propre
/// numérotation — ce ne sont pas deux textes de la même numérotation. Dans
/// l'app, chaque riwaya est un parcours de révision/mémorisation
/// indépendant (config, cycle, progression, historique séparés) : changer
/// de riwaya change de parcours, ne traduit jamais l'un vers l'autre.
enum Riwaya { hafs, warsh }
