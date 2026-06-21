class Hadith {
  final String textFr;
  final String textEn;
  final String sourceFr;
  final String sourceEn;

  const Hadith({
    required this.textFr,
    required this.textEn,
    required this.sourceFr,
    required this.sourceEn,
  });
}

const List<Hadith> motivatingHadiths = [
  Hadith(
    textFr: '« Le meilleur d\'entre vous est celui qui apprend le Coran et l\'enseigne. »',
    textEn: '"The best of you are those who learn the Quran and teach it."',
    sourceFr: 'Rapporté par Al-Boukhâri',
    sourceEn: 'Narrated by Al-Bukhari',
  ),
  Hadith(
    textFr: '« Récitez le Coran, car il interviendra en faveur de ses compagnons le Jour de la Résurrection. »',
    textEn: '"Recite the Quran, for it will come as an intercessor for its companions on the Day of Resurrection."',
    sourceFr: 'Rapporté par Muslim',
    sourceEn: 'Narrated by Muslim',
  ),
  Hadith(
    textFr: '« Celui qui récite le Coran avec aisance sera avec les nobles et pieux anges. »',
    textEn: '"The one who recites the Quran proficiently will be with the noble and righteous angels."',
    sourceFr: 'Rapporté par Al-Boukhâri et Muslim',
    sourceEn: 'Narrated by Al-Bukhari and Muslim',
  ),
  Hadith(
    textFr: '« Celui qui récite une lettre du Livre d\'Allah reçoit une bonne action, et chaque bonne action est multipliée par dix. »',
    textEn: '"Whoever recites a letter from the Book of Allah receives a good deed, and each good deed is multiplied by ten."',
    sourceFr: 'Rapporté par At-Tirmidhi',
    sourceEn: 'Narrated by At-Tirmidhi',
  ),
  Hadith(
    textFr: '« Le cœur qui ne renferme aucun Coran est comme une maison en ruines. »',
    textEn: '"A heart that contains no Quran is like a ruined house."',
    sourceFr: 'Rapporté par At-Tirmidhi',
    sourceEn: 'Narrated by At-Tirmidhi',
  ),
  Hadith(
    textFr: '« Révisez le Coran. Par Celui qui détient mon âme, il s\'échappe plus vite que les chameaux de leurs liens. »',
    textEn: '"Keep refreshing your knowledge of the Quran, for by the One in Whose Hand my soul is, it escapes faster than camels from their hobbles."',
    sourceFr: 'Rapporté par Al-Boukhâri et Muslim',
    sourceEn: 'Narrated by Al-Bukhari and Muslim',
  ),
  Hadith(
    textFr: '« On dira au récitant du Coran : Lis et monte. Récite comme tu récitais dans la vie d\'ici-bas. Ta demeure sera au dernier verset que tu récites. »',
    textEn: '"It will be said to the reciter of the Quran: Read and ascend. Recite as you used to recite in the world. Your abode will be at the last verse you recite."',
    sourceFr: 'Rapporté par Abou Dâoud et At-Tirmidhi',
    sourceEn: 'Narrated by Abu Dawud and At-Tirmidhi',
  ),
  Hadith(
    textFr: '« Les actes les plus aimés d\'Allah sont ceux accomplis régulièrement, même s\'ils sont peu nombreux. »',
    textEn: '"The most beloved deeds to Allah are those done consistently, even if they are few."',
    sourceFr: 'Rapporté par Al-Boukhâri et Muslim',
    sourceEn: 'Narrated by Al-Bukhari and Muslim',
  ),
  Hadith(
    textFr: '« Nul ne mérite plus d\'envier celui à qui Allah a donné le Coran et qui le met en pratique jour et nuit. »',
    textEn: '"No one deserves to be envied except one to whom Allah has given the Quran and who acts upon it day and night."',
    sourceFr: 'Rapporté par Al-Boukhâri',
    sourceEn: 'Narrated by Al-Bukhari',
  ),
  Hadith(
    textFr: '« Les gens du Coran sont les gens d\'Allah et Ses privilégiés. »',
    textEn: '"The people of the Quran are the people of Allah and His chosen ones."',
    sourceFr: 'Rapporté par An-Nasâ\'i et Ibn Mâja',
    sourceEn: 'Narrated by An-Nasa\'i and Ibn Majah',
  ),
];

/// Hadith sur l'intention — affiché dans le banner preview du plan
const Hadith intentionHadith = Hadith(
  textFr: '« Les actes ne valent que par leurs intentions, et chacun n\'obtient que ce qu\'il a eu l\'intention de faire. »',
  textEn: '"Actions are judged by their intentions, and every person will get what they intended."',
  sourceFr: 'Rapporté par Al-Boukhâri et Muslim',
  sourceEn: 'Narrated by Al-Bukhari and Muslim',
);

/// Retourne le hadith motivant du jour (rotation quotidienne).
Hadith hadithDuJour(DateTime date) {
  final index = (date.year * 365 + date.month * 31 + date.day) % motivatingHadiths.length;
  return motivatingHadiths[index];
}
