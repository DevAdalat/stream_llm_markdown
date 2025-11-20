import 'dart:async';

/// A utility class that transforms a stream of text chunks into a stream
/// that emits text character-by-character with a configurable delay.
///
/// This creates a "typewriter effect" where text appears gradually,
/// even when the source stream sends large chunks.
class CharacterEmitter {
  /// Transforms a source stream to emit text character-by-character.
  ///
  /// The [source] stream provides text chunks (could be words, lines, or paragraphs).
  /// The [characterDelay] controls how fast characters are revealed.
  ///
  /// Each emission contains the full accumulated text so far (not just individual characters),
  /// which is required for incremental markdown parsing.
  ///
  /// If [characterDelay] is [Duration.zero], the source stream is returned unchanged.
  static Stream<String> emit({
    required Stream<String> source,
    required Duration characterDelay,
  }) {
    // If delay is zero, pass through without transformation
    if (characterDelay == Duration.zero) {
      return source;
    }

    late final StreamController<String> controller;
    late final StreamSubscription<String> subscription;
    Timer? emitTimer;

    // Buffer for characters waiting to be emitted
    final List<String> characterBuffer = [];
    
    // The accumulated text that has been emitted so far
    String emittedText = '';
    
    // The latest complete text from the source stream
    String latestSourceText = '';
    
    // Whether the source stream has completed
    bool sourceComplete = false;

    void emitNextCharacter() {
      if (characterBuffer.isNotEmpty) {
        // Take one character from buffer and add to emitted text
        emittedText += characterBuffer.removeAt(0);
        
        if (!controller.isClosed) {
          controller.add(emittedText);
        }
      } else if (sourceComplete && !controller.isClosed) {
        // Buffer is empty and source is done - close the controller
        emitTimer?.cancel();
        emitTimer = null;
        controller.close();
      }
    }

    void startEmitTimer() {
      if (emitTimer == null || !emitTimer!.isActive) {
        emitTimer = Timer.periodic(characterDelay, (_) {
          emitNextCharacter();
        });
      }
    }

    void stopEmitTimer() {
      emitTimer?.cancel();
      emitTimer = null;
    }

    controller = StreamController<String>(
      onListen: () {
        // Subscribe to the source stream
        subscription = source.listen(
          (chunk) {
            latestSourceText = chunk;
            
            // Calculate new characters (difference between latest and emitted)
            if (chunk.length > emittedText.length) {
              final newCharacters = chunk.substring(emittedText.length);
              
              // Add new characters to buffer
              for (int i = 0; i < newCharacters.length; i++) {
                characterBuffer.add(newCharacters[i]);
              }
              
              // Start the emit timer if not already running
              startEmitTimer();
            }
          },
          onError: (error, stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () {
            sourceComplete = true;
            // Timer will close controller when buffer is empty
            if (characterBuffer.isEmpty) {
              stopEmitTimer();
              if (!controller.isClosed) {
                controller.close();
              }
            }
          },
        );
      },
      onPause: () {
        subscription.pause();
        stopEmitTimer();
      },
      onResume: () {
        subscription.resume();
        if (characterBuffer.isNotEmpty) {
          startEmitTimer();
        }
      },
      onCancel: () {
        stopEmitTimer();
        subscription.cancel();
      },
    );

    return controller.stream;
  }
}
