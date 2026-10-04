import SwiftUI

public struct NotesView: View {
    @ObservedObject var notes = NotesManager.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header
            IslandHeaderView(
                icon: "note.text",
                iconColor: .yellow,
                title: "Quick Scratchpad"
            ) {
                HStack(spacing: 8) {
                    IslandButton("Copy", icon: "doc.on.doc", variant: .secondary, size: .small) {
                        notes.copyAll()
                    }
                    IslandButton("Clear", variant: .ghost, size: .small) {
                        withAnimation(IslandSpring.bouncy) {
                            notes.clear()
                        }
                    }
                }
            }
            
            // Text Editor
            TextEditor(text: $notes.noteText)
                .font(IslandFont.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(height: 84)
                .padding(.horizontal, 14)
        }
        .padding(.bottom, 6)
    }
}
