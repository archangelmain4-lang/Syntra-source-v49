//
//  FlowLayout.swift
//  Syntra
//
//  Created by occlusion on 5/19/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// A simple flow layout that wraps subviews to new lines when needed.
@available(macOS 13.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat
    /// Optional maximum width constraint. When nil, the layout will rely on the proposed size from the parent. This is
    /// useful in scenarios where the parent view doesn\'t pass an explicit width (e.g. inside a `ScrollView`), which
    /// would otherwise cause the layout to assume an unlimited width and therefore stop wrapping. Supplying a finite
    /// value forces proper line-wrapping behaviour.
    var maxWidth: CGFloat? = nil

    struct Cache {
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        // Determine the width we\'re allowed to consume. Priority:
        // 1. The parent\'s proposed width (if any).
        // 2. An explicit `maxWidth` passed in during initialisation.
        // 3. Screen width * 0.9 as a sensible fallback.

        let screenWidthFallback: CGFloat = {
#if os(macOS)
            return NSScreen.main?.frame.width ?? 800
#else
            return UIScreen.main.bounds.width
#endif
        }() * 0.9

        let availableWidth = proposal.width ?? maxWidth ?? screenWidthFallback

        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        // Measure and wrap
        for size in cache.sizes {
            if rowWidth + size.width > availableWidth {
                maxRowWidth = max(maxRowWidth, rowWidth)
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        maxRowWidth = max(maxRowWidth, rowWidth)
        totalHeight += rowHeight

        // Always occupy the full available width to prevent clipping and ensure alignment with the parent container.
        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        // Place each subview, wrapping when exceeding width
        for (index, subview) in subviews.enumerated() {
            let size = cache.sizes[index]
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
