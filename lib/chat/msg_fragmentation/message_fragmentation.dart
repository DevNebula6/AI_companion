import 'dart:math';

class MessageFragmenter {
  static const int _maxFragmentLength = 120;
  static const int _minFragmentLength = 15;
  static final Random _random = Random();
  
  /// Splits a response into natural conversation fragments with randomness
  static List<String> fragmentResponse(String response) {
    if (response.length <= _maxFragmentLength) {
      return [response.trim()];
    }
    
    final fragments = <String>[];
    
    // Add randomness to fragmentation approach
    final useNaturalBreaks = _random.nextDouble() > 0.3; // 70% chance for natural breaks
    
    if (useNaturalBreaks) {
      final naturalBreaks = _findNaturalBreaks(response);
      if (naturalBreaks.length > 1) {
        return _addConversationalVariations(naturalBreaks);
      }
    }
    
    // Enhanced sentence-based splitting with randomness
    final sentences = _splitIntoSentences(response);
    String currentFragment = '';
    
    for (final sentence in sentences) {
      // Add slight randomness to fragment length thresholds
      final randomThreshold = _maxFragmentLength + _random.nextInt(21) - 10; // ±10 chars
      
      final potentialFragment = currentFragment.isEmpty 
          ? sentence 
          : '$currentFragment $sentence';
      
      if (potentialFragment.length <= randomThreshold) {
        currentFragment = potentialFragment;
      } else {
        if (currentFragment.length >= _minFragmentLength) {
          fragments.add(currentFragment.trim());
        }
        currentFragment = sentence;
      }
    }
    
    if (currentFragment.isNotEmpty) {
      fragments.add(currentFragment.trim());
    }
    
    return _addConversationalVariations(fragments.where((f) => f.isNotEmpty).toList());
  }
  
  /// Add natural conversation variations and hesitations
  static List<String> _addConversationalVariations(List<String> fragments) {
    final enhanced = <String>[];
    
    for (int i = 0; i < fragments.length; i++) {
      String fragment = fragments[i];
      
      // Occasionally add natural hesitations or corrections (10% chance)
      if (_random.nextDouble() < 0.1 && i > 0) {
        final hesitations = [
          'Actually, ',
          'I mean, ',
          'Well, ',
          'Um, ',
          'Let me think... ',
          'Oh wait, ',
          'You know what, '
        ];
        fragment = hesitations[_random.nextInt(hesitations.length)] + fragment.toLowerCase();
      }
      
      // Sometimes split long fragments further for more natural pacing (15% chance)
      if (fragment.length > 80 && _random.nextDouble() < 0.15) {
        final midPoint = fragment.indexOf(' ', fragment.length ~/ 2);
        if (midPoint > 0 && midPoint < fragment.length - 20) {
          enhanced.add(fragment.substring(0, midPoint).trim());
          enhanced.add(fragment.substring(midPoint + 1).trim());
          continue;
        }
      }
      
      enhanced.add(fragment);
    }
    
    return enhanced;
  }
  
  /// Find natural conversation breaks with enhanced patterns
  static List<String> _findNaturalBreaks(String text) {
    // Enhanced patterns with emotional and conversational awareness
    final patterns = [
      // Complete sentence boundaries with emotional weight
      RegExp(r'[.!?]+\s+(?=[A-Z])', multiLine: true),
      
      // Emotional transitions (prioritized)
      RegExp(r'[.!?]+\s+(?=But |And |So |Well |Actually |Oh |Wait |Also |Plus |However |Though |Still |Yet |Besides |Meanwhile |Anyway |Look |Listen |See |You know |I mean |By the way |Honestly |Seriously |Obviously |Basically )', caseSensitive: false),
      
      // Question to statement transitions
      RegExp(r'\?\s+(?=I |You |We |They |It |That |This |Yes |No |Maybe |Probably |Definitely )', caseSensitive: false),
      
      // Strong emotional expressions
      RegExp(r'[.!?]+\s+(?=Wow|Whoa|Hmm|Ugh|Aww|Ooh|Ahh|Haha|Hehe|Yay|Nah|Yeah|Yep|Nope|Damn|Shit|Fuck|Amazing|Incredible|Unbelievable)', caseSensitive: false),
      
      // Conversation flow markers
      RegExp(r'[.!?]+\s+(?=Then|Next|After that|Before|Later|Eventually|Suddenly|Meanwhile|First|Second|Finally)', caseSensitive: false),
      
      // Dramatic pauses and emphasis
      RegExp(r'\.\.\.\s+(?=[A-Z])', multiLine: true),
      RegExp(r'—\s+(?=[A-Z])', multiLine: true),
      
      // Topic shifts
      RegExp(r'[.!?]+\s+(?=Speaking of|Talking about|That reminds me|On that note|Changing topics)', caseSensitive: false),
    ];
    
    // Randomly select pattern strength (affects how aggressive splitting is)
    final patternStrength = _random.nextDouble();
    final patternsToUse = patternStrength > 0.7 ? patterns : patterns.take(4).toList();
    
    for (final pattern in patternsToUse) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        final fragments = <String>[];
        int lastEnd = 0;
        
        for (final match in matches) {
          final fragment = text.substring(lastEnd, match.start + 1).trim();
          if (fragment.length >= _minFragmentLength) {
            fragments.add(fragment);
            lastEnd = match.end;
          }
        }
        
        final remaining = text.substring(lastEnd).trim();
        if (remaining.isNotEmpty && remaining.length >= _minFragmentLength) {
          fragments.add(remaining);
        }
        
        if (fragments.length > 1 && fragments.every((f) => f.trim().length >= _minFragmentLength)) {
          return fragments;
        }
      }
    }
    
    return [text];
  }

  /// Split into sentences (preserving punctuation)
  static List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final pattern = RegExp(r'[.!?]+\s+(?=[A-Z])', multiLine: true);
    final matches = pattern.allMatches(text);
    
    if (matches.isEmpty) {
      return [text];
    }
    
    int lastEnd = 0;
    for (final match in matches) {
      final sentence = text.substring(lastEnd, match.start + 1).trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      lastEnd = match.end;
    }
    
    final remaining = text.substring(lastEnd).trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }
    
    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }
  
  static int calculateTypingDelay(String fragment, int fragmentIndex) {
    // More consistent base delay
    final baseDelay = 1500; // 1.5 seconds base for better UX
    final wordCount = fragment.split(' ').length;
    final typingSpeed = 150; // 150ms per word (slightly slower)
    
    int delay = baseDelay + (wordCount * typingSpeed);
    
    // Emotional content analysis (reduced impact)
    final emotionalWeight = _analyzeEmotionalWeight(fragment);
    delay = (delay * emotionalWeight).round();
    
    // Content-based adjustments
    if (_isQuickReaction(fragment)) {
      delay = (delay * 0.5).round(); // Faster for reactions
    } else if (_isThoughtfulResponse(fragment)) {
      delay = (delay * 1.2).round(); // Slower for thoughtful content
    }
    
    // First fragment gets longer delay
    if (fragmentIndex == 0) {
      delay = (delay * 1.3).round();
    }
    
    // Subsequent fragments get consistent delay
    if (fragmentIndex > 0) {
      delay = (delay * 1.1).round();
    }
    
    // Reduced random variation for more predictable timing
    final variation = (delay * 0.03 * (_random.nextDouble() * 2 - 1)).round();
    delay += variation;
    
    // Consistent bounds with better minimum
    final result = delay.clamp(1200, 4500);
    print('Fragment $fragmentIndex delay: ${result}ms for "$fragment"');
    return result;
  }
  
  /// Analyze emotional weight of content
  static double _analyzeEmotionalWeight(String fragment) {
    final text = fragment.toLowerCase();
    
    // High emotion = longer pauses
    final highEmotionWords = ['love', 'hate', 'amazing', 'terrible', 'incredible', 'awful', 'fantastic', 'horrible'];
    final exclamationCount = fragment.split('!').length - 1;
    final questionCount = fragment.split('?').length - 1;
    
    double weight = 1.0;
    
    // Exclamation/question emphasis
    weight += (exclamationCount * 0.3);
    weight += (questionCount * 0.2);
    
    // Emotional word detection
    for (final word in highEmotionWords) {
      if (text.contains(word)) weight += 0.4;
    }
    
    // Ellipsis indicates thoughtfulness
    if (text.contains('...')) weight += 0.5;
    
    // All caps indicates excitement/urgency
    if (fragment.contains(RegExp(r'[A-Z]{3,}'))) weight += 0.3;
    
    return weight.clamp(0.5, 2.0);
  }
  
  /// Detect quick reaction patterns
  static bool _isQuickReaction(String fragment) {
    final quickPatterns = [
      RegExp(r'^(oh|wow|wait|haha|ugh|hmm|yep|nope|yeah|omg|wtf|lol|yes|no)[\s!?]*', caseSensitive: false),
      RegExp(r'^[a-z]{1,4}[!?]+$', caseSensitive: false),
    ];
    
    return fragment.length < 25 && quickPatterns.any((pattern) => pattern.hasMatch(fragment));
  }
  
  /// Detect thoughtful, complex responses
  static bool _isThoughtfulResponse(String fragment) {
    return fragment.contains(RegExp(r'(actually|honestly|i think|in my opinion|it seems|i believe|perhaps|maybe|probably)', caseSensitive: false)) ||
           fragment.contains('...') ||
           fragment.split(' ').length > 15;
  }
  
  /// Enhanced scroll delay with randomness
  static int calculateScrollDelay(int fragmentIndex) {
    final baseDelay = fragmentIndex == 0 ? 20 : 45;
    final randomVariation = _random.nextInt(20) - 10; // ±10ms variation
    return (baseDelay + randomVariation).clamp(10, 80);
  }
  
  /// Determine if fragment should show avatar (with slight randomness for last fragment)
  static bool shouldShowAvatar(int fragmentIndex, int totalFragments) {
    if (fragmentIndex == totalFragments - 1) {
      // 95% chance to show on last fragment, 5% chance to show on second-to-last for variation
      return _random.nextDouble() < 0.95;
    }
    return false;
  }
  
  /// Check if this is the last fragment
  static bool isLastFragment(int fragmentIndex, int totalFragments) {
    return fragmentIndex == totalFragments - 1;
  }
  
  /// NEW: Determine conversation pacing style based on content
  static String getConversationPacing(List<String> fragments) {
    final totalLength = fragments.join(' ').length;
    final avgFragmentLength = totalLength / fragments.length;
    
    if (avgFragmentLength < 30 && fragments.length > 2) {
      return 'rapid'; // Quick back-and-forth style
    } else if (avgFragmentLength > 60) {
      return 'thoughtful'; // Deliberate, slower style
    } else {
      return 'natural'; // Standard conversational flow
    }
  }
  
  /// NEW: Add natural typing indicators variation
  static bool shouldShowTypingIndicator(int fragmentIndex, String fragment) {
    // Don't show typing for very short reactions
    if (_isQuickReaction(fragment)) {
      return fragmentIndex > 0; // Only show typing after first fragment
    }
    
    // Always show typing for longer, thoughtful responses
    return true;
  }
}