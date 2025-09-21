# HarmoniqSync Development Guide for Claude

## Project Overview
HarmoniqSync is a professional audio/video synchronization application built with SwiftUI and SwiftData. This document provides essential information for Claude to continue development effectively.

## Project Structure
```
Hamoniq Sync/
├── App/
│   ├── Hamoniq_SyncApp.swift          # Main app entry point
│   └── Hamoniq_Sync.entitlements     # App permissions
├── Models/
│   ├── DataModels/                    # SwiftData models
│   │   ├── Project.swift              # Core project container
│   │   ├── MediaGroup.swift           # Smart grouping system
│   │   ├── Clip.swift                 # Individual media files
│   │   ├── SyncResult.swift           # Sync operation results
│   │   ├── SyncJob.swift              # Background processing jobs
│   │   ├── ExportConfiguration.swift # NLE export settings
│   │   ├── UserPreferences.swift     # App settings
│   │   └── ProjectSettings.swift     # Project-specific settings
│   ├── BusinessModels/                # Enums and supporting types
│   │   ├── ProjectType.swift          # Project types (SingleCam, MultiCam, etc.)
│   │   ├── MediaType.swift            # Media file types
│   │   ├── SyncStrategy.swift         # Sync strategies
│   │   ├── AlignmentMethod.swift      # Sync algorithms
│   │   └── SupportingTypes.swift     # Utility types
│   └── DataStore/
│       ├── DataController.swift       # SwiftData container management
│       └── ModelContainer+Extensions.swift
├── ViewModels/
│   ├── Core/                          # Base ViewModel architecture
│   │   ├── BaseViewModel.swift        # Common functionality
│   │   ├── AsyncViewModel.swift       # Async operations
│   │   ├── ObservableViewModel.swift  # State management
│   │   └── ViewModelProtocols.swift   # ViewModel interfaces
│   └── App/
│       └── AppViewModel.swift         # Main app state management
├── Views/
│   ├── App/
│   │   └── ContentView.swift          # Main app container
│   └── Components/                    # Reusable UI components
│       ├── Common/                    # Basic UI building blocks
│       │   ├── TooltipView.swift      # Contextual help
│       │   ├── LoadingOverlayView.swift # Loading states
│       │   ├── ErrorStateView.swift   # Error handling UI
│       │   ├── NotificationView.swift # Toast notifications
│       │   └── AnimatedTransitionView.swift # Smooth transitions
│       ├── Layout/                    # Structure components
│       │   ├── AdaptiveSplitView.swift # Responsive split view
│       │   ├── ResizablePanelView.swift # Draggable panels
│       │   └── ContextualSidebarView.swift # Collapsible sidebar
│       ├── Controls/                  # Interactive elements
│       │   ├── SmartDropZoneView.swift # Intelligent file drop zones
│       │   ├── SliderControlView.swift # Custom sliders
│       │   └── ActionButtonGroupView.swift # Flexible button groups
│       ├── Data/                      # Data presentation
│       │   ├── EmptyStateView.swift   # Beautiful empty states
│       │   ├── SearchableListView.swift # Advanced searchable lists
│       │   └── LoadingStateView.swift # State machines for async ops
│       └── Visualization/             # Audio/video components
│           ├── WaveformView.swift     # Professional audio waveforms
│           ├── VideoThumbnailView.swift # Video thumbnails with timeline
│           └── ConfidenceIndicatorView.swift # Sync confidence visualization
└── Services/
    ├── Core/
    │   ├── ServiceProtocol.swift      # Service interfaces
    │   └── BaseService.swift          # Common service functionality
    ├── Data/
    │   ├── ProjectService.swift       # Project CRUD operations
    │   └── MediaService.swift         # Media import/management
    └── Sync/
        └── SyncService.swift          # Audio sync processing
```

## Build Requirements

### Prerequisites
- Xcode 15.0+
- macOS 14.0+ (Sonoma)
- Swift 5.9+
- SwiftUI 5.0+
- SwiftData (iOS 17.0+, macOS 14.0+)

### Dependencies
- **SwiftData**: Core data persistence
- **Combine**: Reactive programming
- **AVFoundation**: Audio/video processing
- **UniformTypeIdentifiers**: File type handling

### Build Commands
```bash
# Clean build (always run after major changes)
cmd+shift+k  # Clean
cmd+b        # Build

# Run app
cmd+r

# Run tests
cmd+u
```

## Testing Protocol

### After Each Phase - MANDATORY
Before proceeding to the next phase, ALL of the following must pass:

#### 1. Build Tests ✅
```bash
# Clean build test
1. cmd+shift+k (Clean)
2. cmd+b (Build)
3. Verify zero compilation errors
4. Verify zero critical warnings
```

#### 2. Preview Tests ✅
```bash
# Verify all SwiftUI previews work
1. Open each new component file
2. Click "Resume" on preview
3. Verify preview renders correctly
4. Test preview interactions
```

#### 3. Static Analysis ✅
```bash
# Code quality checks
1. Resolve all SwiftLint warnings (if available)
2. Fix all memory leaks
3. Ensure proper error handling
4. Verify accessibility labels
```

#### 4. Component Tests ✅
```bash
# Manual testing checklist
1. Test component in isolation
2. Test with sample data
3. Test error states
4. Test loading states
5. Test user interactions
```

### Test Data Generation
For testing components, use these patterns:

```swift
// Sample project data
let sampleProject = Project(name: "Test Project", type: .multiCam)

// Sample media files
let sampleClips = [
    Clip(url: URL(fileURLWithPath: "/tmp/audio1.wav"), type: .audio),
    Clip(url: URL(fileURLWithPath: "/tmp/video1.mov"), type: .video)
]

// Mock waveform data
let mockWaveform = WaveformData.mock(duration: 60, sampleCount: 200)
```

## Architecture Guidelines

### MVVM Pattern
- **Models**: SwiftData entities in `Models/DataModels/`
- **Views**: SwiftUI views in `Views/`
- **ViewModels**: Business logic in `ViewModels/`
- **Services**: Data and business services in `Services/`

### State Management
- Use `@Published` properties for observable state
- Use `@State` for local view state
- Use `@StateObject` for ViewModel lifecycle management
- Use `@EnvironmentObject` for dependency injection

### Error Handling
- All async operations must handle errors
- Use `Result<Success, Failure>` for complex operations
- Display user-friendly error messages
- Log technical errors for debugging

### Performance Guidelines
- Keep SwiftUI views lightweight
- Use `@State` and `@Published` judiciously
- Implement proper data loading strategies
- Use lazy loading for large lists

## Common Issues and Solutions

### Build Issues
1. **SwiftData namespace conflicts**: Use fully qualified names (e.g., `HarmoniqSync.SyncResult`)
2. **Missing imports**: Ensure all necessary imports are included
3. **Preview crashes**: Check for @MainActor requirements

### Service Integration
1. **Dependency injection**: Pass services via @EnvironmentObject
2. **Async operations**: Always use `@MainActor` for UI updates
3. **Cancellation**: Implement proper cancellation in long-running operations

### Component Usage
1. **Configuration objects**: Use configuration structs for component customization
2. **Callbacks**: Provide optional callbacks for user interactions
3. **Accessibility**: Always include accessibility labels and hints

## Development Workflow

### Phase Completion Checklist
Before marking any phase as complete:

- [ ] All files compile without errors
- [ ] All SwiftUI previews work
- [ ] All components have proper documentation
- [ ] All new features have been tested manually
- [ ] Memory usage is acceptable
- [ ] No obvious performance issues
- [ ] Accessibility is properly implemented
- [ ] Error handling is comprehensive

### Code Style
- Use descriptive variable and function names
- Add proper documentation comments
- Follow Swift naming conventions
- Use SwiftLint recommended style (if available)
- Keep functions focused and single-purpose

### Git Workflow
- Create meaningful commit messages
- Reference related issues or features
- Use conventional commit format when possible

## Next Development Priorities

### Phase 3 Enhancement (Recommended Next)
Focus on completing project management using the new components:

1. **ProjectBrowserView Enhancement**
   - Replace placeholder with SearchableListView
   - Add project filtering and sorting
   - Implement project templates

2. **MediaImportView Implementation**
   - Use SmartDropZoneView for file dropping
   - Add progress tracking with LoadingStateView
   - Implement file validation and error handling

3. **Project Creation Workflow**
   - Enhance NewProjectView with better UX
   - Add project type selection with previews
   - Implement project settings configuration

### Testing Each Enhancement
After implementing each view:
1. Test with empty state (use EmptyStateView)
2. Test with sample data
3. Test error conditions
4. Verify all user interactions work
5. Check SwiftUI preview functionality

## Important Notes

- **Always test on clean build**: Use cmd+shift+k before cmd+b
- **SwiftData threading**: Ensure UI updates happen on @MainActor
- **Preview data**: Use mock data generators for SwiftUI previews
- **Error boundaries**: Wrap async operations in do-catch blocks
- **Memory management**: Use weak references to avoid retain cycles

This document should be consulted before making significant changes to ensure consistency and maintainability.