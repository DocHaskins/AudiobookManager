// lib/utils/genre_icon_utils.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GenreIconUtils {
  // Enhanced genre icon mapping with Font Awesome Icons
  static const Map<String, IconData> _exactGenreIconMap = {
    // Fiction & Literature
    'fiction': FontAwesomeIcons.bookOpen,
    'literature': FontAwesomeIcons.featherPointed,
    'classic': FontAwesomeIcons.landmark,
    'classics': FontAwesomeIcons.landmark,
    'literary fiction': FontAwesomeIcons.bookOpen,
    'contemporary': FontAwesomeIcons.clock,
    'historical fiction': FontAwesomeIcons.book,
    'poetry': FontAwesomeIcons.quoteLeft,
    'anthology': FontAwesomeIcons.bookBookmark,
    'roman': FontAwesomeIcons.archway,
    'politics': FontAwesomeIcons.businessTime,
    'plays': FontAwesomeIcons.masksTheater,
    'Lovecraftian': FontAwesomeIcons.spaghettiMonsterFlying,
    'Food': FontAwesomeIcons.carrot,
    'Book Club': FontAwesomeIcons.book,
    'Apocalyptic': FontAwesomeIcons.radiation,
    
    // Non-Fiction
    'non-fiction': FontAwesomeIcons.newspaper,
    'nonfiction': FontAwesomeIcons.newspaper,
    'essay': FontAwesomeIcons.penNib,
    'memoir': FontAwesomeIcons.userPen,
    'autobiography': FontAwesomeIcons.userPen,
    'biography': FontAwesomeIcons.user,
    
    // Mystery & Crime
    'mystery': FontAwesomeIcons.magnifyingGlass,
    'crime': FontAwesomeIcons.userSecret,
    'true crime': FontAwesomeIcons.handcuffs,
    'detective': FontAwesomeIcons.userSecret,
    'noir': FontAwesomeIcons.moon,
    'thriller': FontAwesomeIcons.bolt,
    'suspense': FontAwesomeIcons.eye,
    
    // Science Fiction & Fantasy
    'sci-fi': FontAwesomeIcons.rocket,
    'science fiction': FontAwesomeIcons.rocket,
    'fantasy': FontAwesomeIcons.hatWizard,
    'dark fantasy': FontAwesomeIcons.skull,
    'urban fantasy': FontAwesomeIcons.city,
    'epic fantasy': FontAwesomeIcons.crown,
    'epic': FontAwesomeIcons.crown,
    'dystopian': FontAwesomeIcons.radiation,
    'dystopia': FontAwesomeIcons.radiation,
    'cyberpunk': FontAwesomeIcons.microchip,
    'steampunk': FontAwesomeIcons.gears,
    'space opera': FontAwesomeIcons.satellite,
    'time travel': FontAwesomeIcons.hourglassHalf,
    
    // Romance
    'romance': FontAwesomeIcons.heart,
    'romantic comedy': FontAwesomeIcons.heart,
    'historical romance': FontAwesomeIcons.heart,
    'paranormal romance': FontAwesomeIcons.heartPulse,
    'contemporary romance': FontAwesomeIcons.heart,
    
    // Horror & Dark
    'horror': FontAwesomeIcons.ghost,
    'supernatural': FontAwesomeIcons.handSparkles,
    'paranormal': FontAwesomeIcons.handSparkles,
    'gothic': FontAwesomeIcons.church,
    'zombie': FontAwesomeIcons.skull,
    'vampire': FontAwesomeIcons.tooth,
    'demons': FontAwesomeIcons.fire,
    'devils': FontAwesomeIcons.fire,
    
    // Adventure & Action
    'adventure': FontAwesomeIcons.compass,
    'action': FontAwesomeIcons.personRunning,
    'military': FontAwesomeIcons.medal,
    'war': FontAwesomeIcons.personMilitaryToPerson,
    'survival': FontAwesomeIcons.tent,
    'spy': FontAwesomeIcons.userNinja,
    'espionage': FontAwesomeIcons.userNinja,
    
    // Fantasy Creatures & Elements
    'dragons': FontAwesomeIcons.dragon,
    'elves': FontAwesomeIcons.leaf,
    'magic': FontAwesomeIcons.wandMagicSparkles,
    'wizards': FontAwesomeIcons.hatWizard,
    'witches': FontAwesomeIcons.broom,
    'dungeons and dragons': FontAwesomeIcons.diceD20,
    'dnd': FontAwesomeIcons.diceD20,
    'd&d': FontAwesomeIcons.diceD20,
    'werewolves': FontAwesomeIcons.wolfPackBattalion,
    
    // Educational & Academic
    'science': FontAwesomeIcons.flask,
    'technology': FontAwesomeIcons.laptop,
    'history': FontAwesomeIcons.scroll,
    'philosophy': FontAwesomeIcons.brain,
    'psychology': FontAwesomeIcons.brain,
    'sociology': FontAwesomeIcons.users,
    'anthropology': FontAwesomeIcons.earthAmericas,
    'political science': FontAwesomeIcons.balanceScale,
    'economics': FontAwesomeIcons.chartLine,
    'mathematics': FontAwesomeIcons.calculator,
    'physics': FontAwesomeIcons.atom,
    'chemistry': FontAwesomeIcons.vial,
    'biology': FontAwesomeIcons.dna,
    'medicine': FontAwesomeIcons.stethoscope,
    'engineering': FontAwesomeIcons.screwdriverWrench,
    
    // Business & Self-Help
    'business': FontAwesomeIcons.briefcase,
    'self-help': FontAwesomeIcons.handHoldingHeart,
    'motivation': FontAwesomeIcons.mountain,
    'leadership': FontAwesomeIcons.chessKing,
    'entrepreneurship': FontAwesomeIcons.lightbulb,
    'marketing': FontAwesomeIcons.bullhorn,
    'finance': FontAwesomeIcons.dollarSign,
    'investing': FontAwesomeIcons.moneyCheck,
    'career': FontAwesomeIcons.suitcase,
    'productivity': FontAwesomeIcons.listCheck,
    
    // Health & Wellness
    'health': FontAwesomeIcons.heartPulse,
    'fitness': FontAwesomeIcons.dumbbell,
    'nutrition': FontAwesomeIcons.appleWhole,
    'mental health': FontAwesomeIcons.brain,
    'wellness': FontAwesomeIcons.spa,
    'meditation': FontAwesomeIcons.om,
    'yoga': FontAwesomeIcons.personPraying,
    'diet': FontAwesomeIcons.carrot,
    
    // Lifestyle & Hobbies
    'cooking': FontAwesomeIcons.plateWheat,
    'recipe': FontAwesomeIcons.utensils,
    'travel': FontAwesomeIcons.plane,
    'photography': FontAwesomeIcons.camera,
    'art': FontAwesomeIcons.palette,
    'music': FontAwesomeIcons.music,
    'sports': FontAwesomeIcons.footballBall,
    'gardening': FontAwesomeIcons.seedling,
    'crafts': FontAwesomeIcons.scissors,
    'diy': FontAwesomeIcons.hammer,
    
    // Religion & Spirituality
    'religion': FontAwesomeIcons.cross,
    'spirituality': FontAwesomeIcons.dove,
    'christianity': FontAwesomeIcons.cross,
    'islam': FontAwesomeIcons.mosque,
    'judaism': FontAwesomeIcons.starOfDavid,
    'buddhism': FontAwesomeIcons.dharmachakra,
    'hinduism': FontAwesomeIcons.om,
    'theology': FontAwesomeIcons.bookBible,
    'mythology': FontAwesomeIcons.bolt,
    
    // Age Categories
    'children': FontAwesomeIcons.child,
    'childrens': FontAwesomeIcons.child,
    'young adult': FontAwesomeIcons.school,
    'teen': FontAwesomeIcons.userGraduate,
    'middle grade': FontAwesomeIcons.school,
    'picture book': FontAwesomeIcons.images,
    
    // Entertainment & Media
    'comedy': FontAwesomeIcons.faceGrinSquint,
    'humor': FontAwesomeIcons.faceGrinTears,
    'drama': FontAwesomeIcons.masksTheater,
    'satire': FontAwesomeIcons.faceGrinWink,
    'entertainment': FontAwesomeIcons.tv,
    
    // Comics & Graphic
    'comics': FontAwesomeIcons.commentDots,
    'graphic novel': FontAwesomeIcons.bookOpen,
    'comic': FontAwesomeIcons.commentDots,
    'manga': FontAwesomeIcons.bookOpen,
    'series': FontAwesomeIcons.layerGroup,
    'short story': FontAwesomeIcons.bookOpenReader,
    'novella': FontAwesomeIcons.bookOpen,
    
    // Special Categories
    'audiobook': FontAwesomeIcons.headphones,
    'podcast': FontAwesomeIcons.microphone,
    
    // Regional/Cultural
    'african': FontAwesomeIcons.earthAfrica,
    'asian': FontAwesomeIcons.earthAsia,
    'european': FontAwesomeIcons.earthEurope,
    'american': FontAwesomeIcons.earthAmericas,
    'latin': FontAwesomeIcons.earthAmericas,
    'indigenous': FontAwesomeIcons.feather,
    
    // Time Periods
    'ancient': FontAwesomeIcons.columns,
    'medieval': FontAwesomeIcons.chessRook,
    'renaissance': FontAwesomeIcons.paintbrush,
    'modern': FontAwesomeIcons.clockRotateLeft,
    'futuristic': FontAwesomeIcons.robot,
    'western': FontAwesomeIcons.hatCowboy,
  };

  // Keywords for "contains" matching with priority
  static const Map<String, IconData> _keywordIconMap = {
    // Fantasy & Magic
    'dragon': FontAwesomeIcons.dragon,
    'magic': FontAwesomeIcons.wandMagicSparkles,
    'wizard': FontAwesomeIcons.hatWizard,
    'witch': FontAwesomeIcons.broom,
    'elf': FontAwesomeIcons.leaf,
    'dwarf': FontAwesomeIcons.hammer,
    'fairy': FontAwesomeIcons.wandMagicSparkles,
    'demon': FontAwesomeIcons.fire,
    'angel': FontAwesomeIcons.dove,
    'vampire': FontAwesomeIcons.tooth,
    'werewolf': FontAwesomeIcons.paw,
    'zombie': FontAwesomeIcons.skull,
    'ghost': FontAwesomeIcons.ghost,
    'superheroes': FontAwesomeIcons.superpowers,
    
    // Sci-Fi & Tech
    'robot': FontAwesomeIcons.robot,
    'alien': FontAwesomeIcons.userAstronaut,
    'space': FontAwesomeIcons.rocket,
    'cyberpunk': FontAwesomeIcons.microchip,
    'ai': FontAwesomeIcons.robot,
    'cyber': FontAwesomeIcons.microchip,
    
    // Crime & Mystery
    'murder': FontAwesomeIcons.skull,
    'kill': FontAwesomeIcons.skull,
    'death': FontAwesomeIcons.skull,
    'police': FontAwesomeIcons.shieldHalved,
    'detective': FontAwesomeIcons.magnifyingGlass,
    'spy': FontAwesomeIcons.userSecret,
    
    // Adventure & Action
    'pirate': FontAwesomeIcons.skull,
    'treasure': FontAwesomeIcons.coins,
    'quest': FontAwesomeIcons.flagCheckered,
    'journey': FontAwesomeIcons.route,
    'exploration': FontAwesomeIcons.compass,
    'war': FontAwesomeIcons.medal,
    'battle': FontAwesomeIcons.personMilitaryPointing,
    
    'Lovecraftian': FontAwesomeIcons.spaghettiMonsterFlying,
    'Food': FontAwesomeIcons.carrot,
    'Book Club': FontAwesomeIcons.book,
    'Apocalyptic': FontAwesomeIcons.radiation,

    // Romance & Emotion
    'love': FontAwesomeIcons.heart,
    'heart': FontAwesomeIcons.heart,
    'wedding': FontAwesomeIcons.ring,
    'marriage': FontAwesomeIcons.ring,
    
    // Horror & Dark
    'blood': FontAwesomeIcons.droplet,
    'dark': FontAwesomeIcons.moon,
    'nightmare': FontAwesomeIcons.moon,
    'fear': FontAwesomeIcons.ghost,
    'terror': FontAwesomeIcons.skull,
    
    // General categories
    'cook': FontAwesomeIcons.carrot,
    'recipe': FontAwesomeIcons.utensils,
    'travel': FontAwesomeIcons.plane,
    'health': FontAwesomeIcons.heartPulse,
    'fitness': FontAwesomeIcons.dumbbell,
    'business': FontAwesomeIcons.briefcase,
    'money': FontAwesomeIcons.dollarSign,
    'rich': FontAwesomeIcons.coins,
    'school': FontAwesomeIcons.school,
    'college': FontAwesomeIcons.graduationCap,
    'university': FontAwesomeIcons.buildingColumns,
    'history': FontAwesomeIcons.book,
    'science': FontAwesomeIcons.flask,
    'technology': FontAwesomeIcons.laptop,
    'art': FontAwesomeIcons.palette,
    'music': FontAwesomeIcons.music,
    'sport': FontAwesomeIcons.footballBall,
    'game': FontAwesomeIcons.gamepad,
    'photo': FontAwesomeIcons.camera,
    'short stories': FontAwesomeIcons.book,
  };

  /// Gets an appropriate icon for a genre string
  static IconData getGenreIcon(String genre) {
    if (genre.isEmpty) return FontAwesomeIcons.tag;
    
    final lowerGenre = genre.toLowerCase().trim();
    
    // 1. Try exact match first
    if (_exactGenreIconMap.containsKey(lowerGenre)) {
      return _exactGenreIconMap[lowerGenre]!;
    }
    
    // 2. Try contains matching with keywords (prioritized by order)
    for (final entry in _keywordIconMap.entries) {
      if (lowerGenre.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 3. Try partial matching with exact genres
    for (final entry in _exactGenreIconMap.entries) {
      if (lowerGenre.contains(entry.key) || entry.key.contains(lowerGenre)) {
        return entry.value;
      }
    }
    
    // 4. Fall back to default category icon
    return FontAwesomeIcons.tag;
  }

  /// Gets multiple possible icons for a genre (useful for UI selection)
  static List<IconData> getSuggestedIcons(String genre) {
    final lowerGenre = genre.toLowerCase().trim();
    final suggestions = <IconData>{};
    
    // Add exact match if found
    if (_exactGenreIconMap.containsKey(lowerGenre)) {
      suggestions.add(_exactGenreIconMap[lowerGenre]!);
    }
    
    // Add keyword matches
    for (final entry in _keywordIconMap.entries) {
      if (lowerGenre.contains(entry.key)) {
        suggestions.add(entry.value);
      }
    }
    
    // Add partial matches
    for (final entry in _exactGenreIconMap.entries) {
      if (lowerGenre.contains(entry.key) || entry.key.contains(lowerGenre)) {
        suggestions.add(entry.value);
      }
    }
    
    // Ensure we have at least the default
    if (suggestions.isEmpty) {
      suggestions.add(FontAwesomeIcons.tag);
    }
    
    return suggestions.toList();
  }

  /// Gets all available genre mappings
  static Map<String, IconData> getAllGenreMappings() {
    return Map.unmodifiable(_exactGenreIconMap);
  }

  /// Checks if a genre has a specific icon mapping
  static bool hasSpecificIcon(String genre) {
    final lowerGenre = genre.toLowerCase().trim();
    
    // Check exact match
    if (_exactGenreIconMap.containsKey(lowerGenre)) {
      return true;
    }
    
    // Check keyword match
    for (final keyword in _keywordIconMap.keys) {
      if (lowerGenre.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
}