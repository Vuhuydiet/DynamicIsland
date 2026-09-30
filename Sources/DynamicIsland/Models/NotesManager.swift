import Foundation
import AppKit
import Combine

public class NotesManager: ObservableObject {
    public static let shared = NotesManager()
    
    private let key = "dynamic_island_quick_note"
    
    @Published public var noteText: String {
        didSet {
            UserDefaults.standard.set(noteText, forKey: key)
        }
    }
    
    private init() {
        self.noteText = UserDefaults.standard.string(forKey: key) ?? "💡 Quick scratchpad for thoughts, links, and temporary snippets..."
    }
    
    public func clear() {
        noteText = ""
        SoundManager.shared.play(.click)
    }
    
    public func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(noteText, forType: .string)
        SoundManager.shared.play(.click)
    }
}
