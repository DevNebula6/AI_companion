class MessageFragmenter {
  static const int _maxFragmentLength = 120;
  static const int _minFragmentLength = 15;
  
  /// Splits a response into natural conversation fragments
  static List<String> fragmentResponse(String response) {
    if (response.length <= _maxFragmentLength) {
      return [response.trim()];
    }
    
    final fragments = <String>[];
    
    // First, try to split by natural conversation breaks
    final naturalBreaks = _findNaturalBreaks(response);
    if (naturalBreaks.length > 1) {
      return naturalBreaks.where((f) => f.trim().isNotEmpty).toList();
    }
    
    // Fallback to sentence-based splitting
    final sentences = _splitIntoSentences(response);
    String currentFragment = '';
    
    for (final sentence in sentences) {
      final potentialFragment = currentFragment.isEmpty 
          ? sentence 
          : '$currentFragment $sentence';
      
      if (potentialFragment.length <= _maxFragmentLength) {
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
    
    return fragments.where((f) => f.isNotEmpty).toList();
  }
  
  /// Find natural conversation breaks
  static List<String> _findNaturalBreaks(String text) {
    // Look for natural conversation patterns
    final patterns = [
      // Conversational transitions with emotional emphasis
      RegExp(r'[.!?]+\s+(?=But |And |So |Well |Actually |Oh |Wait |Also |Plus |However |Though |Still |Yet |Besides |Meanwhile |Anyway |Look |Listen |See |You know |I mean |By the way )', caseSensitive: false),
            
      // Lists and enumeration
      RegExp(r'(?<=\d\.|\-|\*|\•)\s+(?=[A-Z])', multiLine: true),
      RegExp(r'(?<=first|second|third|finally|lastly)[,:]?\s+(?=[A-Z])', caseSensitive: false),
      
      // Emphasis and dramatic pauses
      RegExp(r'[.!?]+\s+(?=[A-Z])'),
      RegExp(r'—\s+'),
      RegExp(r'\.\.\.\s*'),
      RegExp(r':\s+(?=[A-Z])'),
      
      // Emotional expressions and interjections
      RegExp(r'(?<=\w)[.!?]+\s+(?=Wow|Whoa|Hmm|Ugh|Aww|Ooh|Ahh|Haha|Hehe|Yay|Nah|Yeah|Yep|Nope)', caseSensitive: false),
      
      // Question to statement transitions
      RegExp(r'\?\s+(?=I |You |We |They |It |That |This )', caseSensitive: false),
      
      // Parenthetical breaks
      RegExp(r'\)\s+(?=[A-Z])'),
      
      // Time and sequence indicators
      RegExp(r'(?<=then|next|after that|before|later|eventually|suddenly|meanwhile)[,:]?\s+(?=[A-Z])', caseSensitive: false),
    ];
      
    for (final pattern in patterns) {
      final parts = text.split(pattern);
      if (parts.length > 1 && parts.every((p) => p.trim().length >= _minFragmentLength)) {
        return parts.map((p) => p.trim()).toList();
      }
    }
    
    return [text];
  }
  
  /// Split into sentences
  static List<String> _splitIntoSentences(String text) {
    return text
        .split(RegExp(r'[.!?]+\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  
  /// Calculate typing delay for natural feel with improved timing
  static int calculateTypingDelay(String fragment, int fragmentIndex) {
    final baseDelay = 500; // Slightly reduced for smoother avatar transitions
    final wordCount = fragment.split(' ').length;
    final typingSpeed = 80; // Optimized for visual flow
    
    int delay = baseDelay + (wordCount * typingSpeed);
    
    // Emotional emphasis gets longer pauses
    if (fragment.contains(RegExp(r'[!]{2,}|[?]{2,}|\.\.\.'))) {
      delay += 200; 
    }
    
    // Quick reactions are faster
    if (fragment.length < 25 && 
        fragment.toLowerCase().startsWith(RegExp(r'^(oh|wow|wait|haha|ugh|hmm)'))) {
      delay = delay ~/ 2;
    }
    
    // First fragment can be immediate for quick reactions
    if (fragmentIndex == 0 && fragment.length < 20) {
      delay = delay ~/ 3;
    }
    
    return delay.clamp(100, 1600); // Optimized range
  }
  
  /// Calculate scroll delay to ensure proper timing for avatar transitions
  static int calculateScrollDelay(int fragmentIndex) {
    // Faster scroll timing for smoother avatar movement
    return fragmentIndex == 0 ? 25 : 60; 
  }
  
  /// NEW: Determine if fragment should show avatar
  static bool shouldShowAvatar(int fragmentIndex, int totalFragments) {
    // Show avatar only on the last fragment
    return fragmentIndex == totalFragments - 1;
  }
  
  /// NEW: Determine if this is the last fragment in a sequence
  static bool isLastFragment(int fragmentIndex, int totalFragments) {
    return fragmentIndex == totalFragments - 1;
  }
}