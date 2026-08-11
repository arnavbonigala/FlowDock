//
//  ShelfActivity.swift
//  FlowDock
//

import AppKit
import KeyboardShortcuts
import Defaults
import SwiftUI
import UniformTypeIdentifiers

extension Activity {
    static let shelfID = "shelf"

    static func shelf(count: Int) -> Activity {
        Activity(
            id: shelfID,
            activityClass: .persistent,
            band: .drag,
            label: shelfLabel(count: count),
            chinSideWidth: Activity.chinSide,
            leading: {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinSide, alignment: .leading)
            },
            trailing: {
                Text(count > 0 ? "\(count)" : "")
                    .font(.chinValue)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinSide, alignment: .trailing)
            }
        )
    }

    static func shelfLabel(count: Int) -> String {
        switch count {
        case 0: "Shelf, receiving"
        case 1: "Shelf, 1 item"
        default: "Shelf, \(count) items"
        }
    }
}

extension View {
    func shelfActivity(in store: ActivityStore, receiving: Bool) -> some View {
        modifier(ShelfActivityBinder(store: store, receiving: receiving))
    }
}

private struct ShelfActivityBinder: ViewModifier {
    let store: ActivityStore
    let receiving: Bool

    @ObservedObject private var shelf = ShelfStateViewModel.shared

    private struct Snapshot: Equatable {
        var live: Bool
        var count: Int
    }

    private var snapshot: Snapshot {
        Snapshot(live: receiving || shelf.isLoading, count: shelf.items.count)
    }

    func body(content: Content) -> some View {
        content.onChange(of: snapshot, initial: true) { _, now in
            if now.live {
                store.begin(.shelf(count: now.count))
            } else {
                store.end(Activity.shelfID)
            }
        }
    }
}

// MARK: - Expanded panel

struct ShelfPanel: View {
    let targeted: Bool

    @StateObject private var quickLook = QuickLookService()
    @ObservedObject private var shelf = ShelfStateViewModel.shared
    @ObservedObject private var selection = ShelfSelectionModel.shared

    static let rowHeight: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                QuickShareButton()

                strip

                if !shelf.items.isEmpty {
                    HoverButton(icon: "xmark.bin", scale: .medium) { ShelfActionService.clearShelf() }
                        .iconLabel("Clear the shelf")
                }
            }
            .frame(height: Self.rowHeight)

            ShelfActionRow(quickLook: quickLook)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-4)
                .opacity(targeted ? 1 : 0)
                .allowsHitTesting(false)
        }
        .task { shelf.cleanupInvalidItems() }
        .onChange(of: selection.selectedIDs) { _, _ in syncQuickLook() }
    }

    @ViewBuilder
    private var strip: some View {
        if shelf.items.isEmpty {
            Text(targeted ? "Drop to keep" : "Drop files here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { selection.clear() }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(shelf.items) { item in
                        ShelfChip(item: item, quickLook: quickLook)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func syncQuickLook() {
        guard quickLook.isQuickLookOpen else { return }
        let urls = selection.selectedItems(in: shelf.items).compactMap(Self.previewURL)
        guard !urls.isEmpty else { return }
        quickLook.updateSelection(urls: urls)
    }

    static func previewURL(_ item: ShelfItem) -> URL? {
        if let fileURL = item.fileURL { return fileURL }
        if case .link(let url) = item.kind { return url }
        return nil
    }
}

private struct ShelfActionRow: View {
    let quickLook: QuickLookService

    @ObservedObject private var shelf = ShelfStateViewModel.shared
    @ObservedObject private var selection = ShelfSelectionModel.shared

    @State private var anchor: NSView?
    @State private var runner: ShelfItemViewModel?

    private var items: [ShelfItem] { selection.selectedItems(in: shelf.items) }
    private var files: [URL] { items.compactMap(\.fileURL) }
    private var images: [URL] { files.filter { ImageProcessingService.shared.isImageFile($0) } }
    private var previews: [URL] { items.compactMap(ShelfPanel.previewURL) }

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: 4) {
                if !previews.isEmpty {
                    HoverButton(icon: "eye", scale: .small) { quickLook.show(urls: previews) }
                        .iconLabel("Quick Look")
                }

                HoverButton(icon: "doc.on.doc", scale: .small) { ShelfActionService.copySelection() }
                    .iconLabel("Copy")

                if !files.isEmpty {
                    HoverButton(icon: "doc.zipper", scale: .small) { run(.compress) }
                        .iconLabel("Compress")
                }

                if images.count == 1 {
                    HoverButton(icon: "wand.and.stars", scale: .small) { run(.removeBackground) }
                        .iconLabel("Remove the background")
                }

                if !images.isEmpty {
                    HoverButton(icon: "doc.richtext", scale: .small) { run(.createPDF) }
                        .iconLabel("Create a PDF")
                }

                Menu {
                    if images.count == 1 {
                        Button("Convert Image…") { run(.convertImage) }
                    }
                    if items.count == 1, !files.isEmpty {
                        Button("Rename") { run(.rename) }
                    }
                    if !files.isEmpty {
                        Button("Show in Finder") { run(.showInFinder) }
                        Button("Copy Path") { run(.copyPath) }
                    }
                    Button("Open") { run(.open) }
                    Divider()
                    Button("Remove") { ShelfActionService.removeSelected() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .iconLabel("More actions")

                Spacer(minLength: 0)

                Text(items.count == 1 ? "1 selected" : "\(items.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 22)
            .background(ShareAnchor(view: $anchor))
        } else if !shelf.items.isEmpty {
            Text("Select an item for actions")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(height: 22)
        }
    }

    private func run(_ action: ShelfAction) {
        guard let item = items.first, let anchor else { return }
        let runner = ShelfItemViewModel(item: item)
        self.runner = runner
        runner.perform(action, in: anchor)
    }
}

private struct QuickShareButton: View {
    @ObservedObject private var quickShare = QuickShareService.shared
    @Default(.quickShareProvider) private var providerID

    @State private var anchor: NSView?

    private var provider: QuickShareProvider {
        quickShare.availableProviders.first { $0.id == providerID }
            ?? QuickShareProvider(id: "System Share Menu", imageData: nil, supportsRawText: true)
    }

    var body: some View {
        Button {
            Task { await quickShare.share(Self.sharedItems(), using: provider, from: anchor) }
        } label: {
            glyph
                .frame(width: 18, height: 18)
                .frame(width: ShelfPanel.rowHeight, height: ShelfPanel.rowHeight)
                .panelRowBackground()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(quickShare.isPickerOpen)
        .iconLabel("Share with \(provider.id)")
        .background(ShareAnchor(view: $anchor))
    }

    static func sharedItems() -> [ShelfItem] {
        let items = ShelfStateViewModel.shared.items
        let selected = ShelfSelectionModel.shared.selectedItems(in: items)
        return selected.isEmpty ? items : selected
    }

    @ViewBuilder
    private var glyph: some View {
        if let data = provider.imageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "square.and.arrow.up")
                .font(.panelControl)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShareAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let host = NSView(frame: .zero)
        Task { @MainActor in view = host }
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Items

private struct ShelfChip: View {
    let item: ShelfItem
    let quickLook: QuickLookService

    @StateObject private var viewModel: ShelfItemViewModel
    @ObservedObject private var selection = ShelfSelectionModel.shared

    init(item: ShelfItem, quickLook: QuickLookService) {
        self.item = item
        self.quickLook = quickLook
        _viewModel = StateObject(wrappedValue: ShelfItemViewModel(item: item))
    }

    private var isSelected: Bool { selection.isSelected(item.id) }

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: viewModel.thumbnail ?? item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)

            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .frame(height: ShelfPanel.rowHeight)
        .frame(maxWidth: 140)
        .panelRowBackground()
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
        }
        .overlay {
            ShelfChipInput(item: item, viewModel: viewModel)
        }
        .accessibilityElement(children: .ignore)
        .iconLabel(item.isTemporary ? "\(item.displayName), temporary file" : item.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction {
            ShelfSelectionModel.shared.selectSingle(item)
            ShelfActionService.open(item)
        }
        .accessibilityAction(named: "Quick Look") {
            guard let url = ShelfPanel.previewURL(item) else { return }
            quickLook.show(urls: [url])
        }
        .accessibilityAction(named: "Remove") {
            ShelfStateViewModel.shared.remove(item, deletingStoredData: false)
        }
        .task {
            viewModel.onQuickLookRequest = { quickLook.show(urls: $0) }
            await viewModel.loadThumbnail()
        }
    }
}

private struct ShelfChipInput: NSViewRepresentable {
    let item: ShelfItem
    let viewModel: ShelfItemViewModel

    func makeNSView(context: Context) -> InputView {
        let view = InputView()
        view.item = item
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: InputView, context: Context) {
        nsView.item = item
        nsView.viewModel = viewModel
    }

    final class InputView: NSView, NSDraggingSource {
        var item: ShelfItem!
        weak var viewModel: ShelfItemViewModel?

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []

        override func rightMouseDown(with event: NSEvent) {
            viewModel?.handleRightClick(event: event, view: self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            viewModel?.handleClick(event: event, view: self)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }

            let distance = hypot(
                event.locationInWindow.x - start.locationInWindow.x,
                event.locationInWindow.y - start.locationInWindow.y
            )

            guard distance > dragThreshold else {
                super.mouseDragged(with: event)
                return
            }

            mouseDownEvent = nil
            startDragSession(with: event)
        }

        private func startDragSession(with event: NSEvent) {
            let selected = ShelfSelectionModel.shared.selectedItems(in: ShelfStateViewModel.shared.items)
            let items = selected.count > 1 && selected.contains { $0.id == item.id } ? selected : [item!]

            releaseDraggedURLs()

            let image = viewModel?.thumbnail ?? item.icon
            var draggable: [ShelfItem] = []
            let dragging: [NSDraggingItem] = items.compactMap { item in
                guard let pasteboardItem = pasteboardItem(for: item) else { return nil }
                draggable.append(item)
                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
                draggingItem.setDraggingFrame(
                    NSRect(origin: .zero, size: image.size),
                    contents: image
                )
                return draggingItem
            }

            guard !dragging.isEmpty else {
                releaseDraggedURLs()
                return
            }

            draggedItems = draggable
            beginDraggingSession(with: dragging, event: event, source: self)
        }

        private func releaseDraggedURLs() {
            draggedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()
        }

        private func pasteboardItem(for item: ShelfItem) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()

            switch item.kind {
            case .file:
                guard let url = ShelfStateViewModel.shared.resolveFileURL(for: item) else { return nil }
                if url.startAccessingSecurityScopedResource() {
                    draggedURLs.append(url)
                }
                pasteboardItem.setString(url.absoluteString, forType: .fileURL)
                pasteboardItem.setString(url.path, forType: .string)
            case .text(let string):
                pasteboardItem.setString(string, forType: .string)
            case .link(let url):
                pasteboardItem.setString(url.absoluteString, forType: .URL)
                pasteboardItem.setString(url.absoluteString, forType: .string)
            }

            return pasteboardItem
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            if Defaults[.copyOnDrag] { return [.copy] }

            switch context {
            case .outsideApplication: return [.copy, .move]
            case .withinApplication: return [.copy, .move, .generic]
            @unknown default: return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            ShelfSelectionModel.shared.beginDrag()
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            ShelfSelectionModel.shared.endDrag()

            releaseDraggedURLs()

            if Defaults[.autoRemoveShelfItems] && !operation.isEmpty {
                draggedItems.forEach { ShelfStateViewModel.shared.remove($0, deletingStoredData: false) }
            }
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}

#if DEBUG
extension ShelfPanel {
    static func selfCheck() {
        assert(Activity.shelfLabel(count: 0) == "Shelf, receiving")
        assert(ExperienceView.expandedShortcuts.count == 5, "every shelf shortcut is live only while open")
        assert(ExperienceView.expandedShortcuts.contains(.shelfClear))
        assert(Activity.shelfLabel(count: 1) == "Shelf, 1 item")
        assert(Activity.shelfLabel(count: 4) == "Shelf, 4 items")
        assert(Activity.shelf(count: 2).band == .drag, "nothing outranks a drop in progress")
        assert(Activity.shelf(count: 2).activityClass == .persistent)
        assert(Activity.shelf(count: 2).expanded == nil, "the shelf is panel content, not an expanded activity")
        assert(NSItemProvider.isFileContentType(UTType.png.identifier), "promised attachment content becomes a file")
        assert(NSItemProvider.isFileContentType(UTType.pdf.identifier), "promised attachment content becomes a file")
        assert(!NSItemProvider.isFileContentType(UTType.utf8PlainText.identifier), "dragged text stays text")
        assert(!NSItemProvider.isFileContentType(UTType.fileURL.identifier), "file references resolve to the original file")
        assert(!NSItemProvider.isFileContentType(UTType.url.identifier), "web links stay links")
        assert(TemporaryFileStorageService.isOwnFolder(UUID().uuidString))
        assert(TemporaryFileStorageService.isOwnFolder("zip_\(UUID().uuidString)"))
        assert(!TemporaryFileStorageService.isOwnFolder("com.apple.WebKit"), "the sweep never leaves FlowDock's own folders")
        assert(!TemporaryFileStorageService.isOwnFolder("zip_archive"))
        assert(!TemporaryFileStorageService.isOwnFolder("TemporaryItems"))
    }
}

#Preview {
    ShelfPanel(targeted: false)
        .frame(width: 380)
        .padding(24)
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
