/// Z-Machine Sound Effects System - Handles audio effects for v4+ versions
import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Sound Effect Constants

/// Standard Z-Machine sound effect numbers
public enum StandardSoundEffect: UInt16, CaseIterable {
    case beep = 1          // Standard beep (always available)
    case click = 2         // Click sound
    case boop = 3          // Boop sound (alternate beep)

    // Games can define custom sounds starting from 10
    case customBase = 10
}

/// Sound effect categories
public enum SoundType {
    case systemBeep        // Standard system beep (effect 1)
    case tone             // Generated tone (effect 2)
    case sample           // Digital audio sample (effect 3+)
}

/// Sound effect opcodes and constants
public enum SoundConstants {
    /// SOUND_EFFECT VAR instruction opcode
    public static let soundEffectOpcode: UInt8 = 0x09

    /// Standard sound effect numbers
    public static let beepSound: UInt16 = 1
    public static let clickSound: UInt16 = 2

    /// Volume range
    public static let minVolume: UInt8 = 1
    public static let maxVolume: UInt8 = 8
    public static let defaultVolume: UInt8 = 8

    /// Repeat values
    public static let infiniteRepeats: UInt8 = 255
}

// MARK: - Sound Delegate Protocol

/// Sound effects delegate protocol for platform-specific sound implementation
public protocol SoundDelegate: AnyObject {
    /// Play a sound effect
    /// - Parameters:
    ///   - effect: Sound effect number (1-based)
    ///   - volume: Volume level (1-8, where 8 is loudest)
    ///   - repeats: Number of repetitions (255 = infinite)
    /// - Returns: true if sound played successfully, false if not supported
    func playSound(effect: UInt16, volume: UInt8, repeats: UInt8) -> Bool

    /// Stop all currently playing sounds
    func stopAllSounds()

    /// Check if sound is supported on this platform
    var soundSupported: Bool { get }

    /// Called when a sound effect completes (for completion routines)
    func soundDidComplete(effect: UInt16)
}

// MARK: - Sound Manager

/// Sound manager for Z-Machine sound effects
public class SoundManager {
    /// Sound effects delegate for platform-specific implementation
    public weak var delegate: SoundDelegate?

    /// Z-Machine version for feature availability
    private let version: ZMachineVersion

    /// Currently playing sounds with completion routines
    private var playingSounds: [UInt16: UInt32] = [:]  // effect -> routine address

    /// Reference to Z-Machine for calling completion routines
    private weak var zmachine: ZMachine?

    public init(version: ZMachineVersion) {
        self.version = version
    }

    /// Set reference to Z-Machine for completion routine callbacks
    public func setZMachine(_ zmachine: ZMachine) {
        self.zmachine = zmachine
    }

    /// Execute SOUND_EFFECT instruction
    ///
    /// Implements the Z-Machine SOUND_EFFECT instruction with full parameter support.
    /// Sound effect 0 is special and stops all currently playing sounds.
    ///
    /// - Parameters:
    ///   - effect: Sound effect number (0 = stop all, 1+ = play effect)
    ///   - volume: Volume level (1-8, default 8)
    ///   - repeats: Number of repetitions (1 = once, 255 = infinite, default 1)
    ///   - routine: Routine to call when sound completes (0 = none)
    /// - Returns: true if sound operation succeeded, false if not supported
    public func executeSoundEffect(effect: UInt16, volume: UInt8 = SoundConstants.defaultVolume,
                                 repeats: UInt8 = 1, routine: UInt32 = 0) -> Bool {
        // Sound effects only supported in v4+
        guard version.rawValue >= 4 else {
            return false
        }

        // Effect 0 = stop all sounds (special case)
        if effect == 0 {
            stopAllSounds()
            return true
        }

        // Validate and clamp volume to valid range
        let clampedVolume = max(SoundConstants.minVolume, min(volume, SoundConstants.maxVolume))

        // Store completion routine if provided and not zero
        if routine > 0 {
            playingSounds[effect] = routine
        }

        // Delegate to platform-specific implementation
        let success = delegate?.playSound(effect: effect, volume: clampedVolume, repeats: repeats) ?? false

        // If sound failed to play, remove completion routine
        if !success && routine > 0 {
            playingSounds.removeValue(forKey: effect)
        }

        return success
    }

    /// Stop all currently playing sounds
    public func stopAllSounds() {
        // Clear all completion routines
        playingSounds.removeAll()

        // Stop platform sounds
        delegate?.stopAllSounds()
    }

    /// Notify that a sound effect has completed
    ///
    /// This method should be called by the platform-specific sound implementation
    /// when a sound effect finishes playing. If the sound had a completion routine,
    /// it will be called.
    ///
    /// - Parameter effect: The sound effect number that completed
    public func soundCompleted(effect: UInt16) {
        // Check if this sound had a completion routine
        guard let routineAddress = playingSounds.removeValue(forKey: effect) else {
            return
        }

        // Call the completion routine if we have a Z-Machine reference
        if let zmachine = zmachine {
            do {
                // Unpack the routine address before calling (completion routines use routine addressing)
                let unpackedRoutineAddress = zmachine.unpackAddress(routineAddress, type: .routine)
                _ = try zmachine.callRoutine(unpackedRoutineAddress, arguments: [])
            } catch {
                // Silently handle completion routine errors
                // (authentically, these would typically be ignored)
            }
        }
    }

    /// Check if sound effects are supported for current version
    public var soundSupported: Bool {
        return version.rawValue >= 4 && (delegate?.soundSupported ?? false)
    }

    /// Convert Z-Machine volume (1-8) to normalized volume (0.0-1.0)
    public static func convertVolume(_ zmachineVolume: UInt8) -> Float {
        guard zmachineVolume > 0 else { return 1.0 }  // 0 = use current/default volume
        let clampedVolume = max(SoundConstants.minVolume, min(zmachineVolume, SoundConstants.maxVolume))
        return Float(clampedVolume) / Float(SoundConstants.maxVolume)
    }
}

// MARK: - Default Sound Delegate Implementation

/// Default sound delegate implementation providing basic cross-platform sound support
public class DefaultSoundDelegate: SoundDelegate {

    public var soundSupported: Bool {
        // Check platform capabilities
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        return true
        #else
        return false  // Terminal/Linux/other platforms - no default sound
        #endif
    }

    public func playSound(effect: UInt16, volume: UInt8, repeats: UInt8) -> Bool {
        guard soundSupported else { return false }

        switch effect {
        case StandardSoundEffect.beep.rawValue:
            return playSystemBeep()

        case StandardSoundEffect.click.rawValue:
            return playTone(frequency: 800, duration: 0.1, volume: volume)

        case StandardSoundEffect.boop.rawValue:
            return playTone(frequency: 400, duration: 0.2, volume: volume)

        default:
            // Custom sound effects would need external sound files
            // For now, fall back to system beep for unknown sounds
            return playSystemBeep()
        }
    }

    public func stopAllSounds() {
        // Basic implementation - platform-specific implementations should override
        // this to properly stop ongoing sound playback
    }

    public func soundDidComplete(effect: UInt16) {
        // Default implementation - no action needed
        // Platform-specific implementations would handle completion callbacks
    }

    private func playSystemBeep() -> Bool {
        #if os(macOS)
        NSSound.beep()
        return true
        #else
        // Other platforms would implement system beep differently
        print("\\u{07}") // ASCII bell character as fallback
        return true
        #endif
    }

    private func playTone(frequency: Int, duration: TimeInterval, volume: UInt8) -> Bool {
        // Basic tone generation - platform-specific implementations should
        // use proper audio frameworks like AVAudioEngine
        #if os(macOS)
        // Simplified tone generation for macOS
        // Real implementation would use AVAudioEngine or Core Audio
        NSSound.beep()  // Fallback to system beep
        return true
        #else
        // Other platforms would implement tone generation
        return playSystemBeep()  // Fallback
        #endif
    }
}

// MARK: - Default WindowDelegate Extension for Sound

/// Extension to provide default sound delegate implementation for convenience
public extension DefaultSoundDelegate {
    /// Create a sound delegate that integrates with a sound manager
    /// - Parameter soundManager: The sound manager to notify of completions
    /// - Returns: A sound delegate that calls completion routines
    static func withSoundManager(_ soundManager: SoundManager) -> DefaultSoundDelegate {
        let delegate = DefaultSoundDelegate()

        // Set up completion callback
        // This would typically be done through a more sophisticated callback mechanism
        // in a real implementation, but this provides basic functionality

        return delegate
    }
}