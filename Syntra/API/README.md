# API Integration Guide

This directory contains all API-related code for integrating with the Syntra backend server.

## Structure

-   **APIConfig.swift** - Central configuration for server URLs and common settings
-   **APIClient.swift** - General-purpose HTTP client for making REST API calls
-   **WebSocketManager.swift** - Base class for WebSocket connections
-   **ContextSearchAPI.swift** - WebSocket-based API for real-time context search
-   **NotesAPI.swift** - REST API example for notes operations

## Server Configuration

The base server URL is configured in `APIConfig.swift`:

```swift
static let baseURL = "https://api.syntra.cc"
```

## Usage Examples

### 1. WebSocket Context Search (AutoContextOverlay)

The context search API is automatically integrated with `AutoContextOverlay`. When the overlay is toggled:

1. A WebSocket connection is established
2. Screen OCR text is captured
3. The text is sent to the server for context search
4. Related notes are received and displayed in the overlay

```swift
// The integration happens automatically in AutoContextOverlay.swift
func toggle() {
    if overlayWindow.isVisible {
        stop()
        contextManager.disconnect()
    } else {
        contextManager.connect()
        // ... capture screen text ...
        contextManager.searchContext(screenOCR: combinedText)
        start()
    }
}
```

### 2. REST API Calls

For regular HTTP endpoints, use the `APIClient` through service classes:

```swift
// Example: Search for notes
NotesAPI.shared.searchNotes(keyword: "philosophy")
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { notes in
            print("Found \(notes.count) notes")
        }
    )
    .store(in: &cancellables)
```

### 3. Creating Custom API Services

To add a new API service:

1. Create a new file in the API folder (e.g., `TagsAPI.swift`)
2. Use `APIClient.shared` for HTTP requests or extend `WebSocketManager` for WebSocket connections
3. Define request/response models as needed

Example structure:

```swift
class TagsAPI {
    static let shared = TagsAPI()
    private let apiClient = APIClient.shared

    func getAllTags() -> AnyPublisher<[Tag], APIClient.APIError> {
        return apiClient.request(
            endpoint: "/tags",
            method: .get
        )
    }
}
```

## Models

### Note Model

The `Note` model (in `Models/Note.swift`) matches the backend `WeaviateNote` structure:

-   Handles nested `properties` structure from backend
-   Includes all fields like title, content, tags, connections, etc.
-   Custom encoding/decoding for backend compatibility

### Tag Model

The existing `Tag` model (in `Models/Tag.swift`) is used for note tags:

-   Contains `uniqueid`, `name`, and `color`
-   Provides SwiftUI color conversion utilities

## Error Handling

The `APIClient.APIError` enum provides comprehensive error types:

-   `invalidURL` - Malformed URL
-   `invalidResponse` - Server returned invalid response
-   `httpError(statusCode:data:)` - HTTP error with status code
-   `decodingError` - JSON decoding failed
-   `encodingError` - Request encoding failed
-   `networkError` - Network connectivity issues

## WebSocket Connection States

The `ContextSearchAPI` manages connection states:

-   `isConnected` - WebSocket connection status
-   `isSearching` - Active search in progress
-   `searchResults` - Latest search results
-   `connectionError` - Any connection errors

## Integration Points

1. **AutoContextOverlay** - Uses `ContextSearchAPI` for real-time note suggestions
2. **Views/Controllers** - Can use any API service through dependency injection or singleton access
3. **ViewModels** - Example `NotesViewModel` shows proper Combine usage with APIs

## Testing

To test the API integration:

1. Ensure the server is running at the configured URL
2. Toggle the AutoContext overlay (it will connect and search automatically)
3. Check console logs for connection status and results
4. Use the example `NotesViewModel` methods to test REST endpoints
