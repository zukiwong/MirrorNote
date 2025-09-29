# MirrorNote

A SwiftUI-based iOS app for emotional awareness and cognitive reframing, featuring AI-powered responses to help users process their emotions.

## Features

###  Core Functionality
- **Emotion Recording**: Capture detailed emotional experiences with guided questions
- **Cognitive Processing**: Structured reframing exercises for emotional regulation
- **AI Integration**: Receive personalized AI responses via Gemini API
- **History Management**: Track emotional patterns and growth over time
- **Smart Inbox**: Organize and manage AI replies

###  User Experience
- **Immersive Input**: Full-screen question interface for focused reflection
- **Adaptive UI**: Dynamic keyboard handling and auto-expanding text fields
- **Dark Mode**: Complete dark mode support
- **Intuitive Navigation**: Tab-based interface with gesture support

## Technical Stack

### Platform & Requirements
- **iOS**: 16.6+
- **Language**: Swift 5.0
- **Framework**: SwiftUI
- **Architecture**: MVVM

### External Services
- **Firebase**: Analytics, Remote Config for AI prompt management
- **Gemini AI**: Natural language processing and response generation

## Architecture

### Application Flow
```
MirrorNoteApp → MainTabView
    ├── Home (Record & Process emotions)
    ├── History (Past entries with search)
    ├── Inbox (AI responses)
    └── Settings (App configuration)
```

### Key Components
- **EmotionContextViewModel**: Shared state for date, location, and people
- **QuestionBlock**: Reusable UI component for guided questions
- **EmotionInputField**: Auto-expanding text input with UIKit bridge
- **AIReplyService**: Gemini API integration with configurable prompts

## Development

### Building the Project
```bash
# Open in Xcode
open "MirrorNote.xcodeproj"

# Build from command line
xcodebuild -project "MirrorNote.xcodeproj" -scheme "MirrorNote" build

# Run tests
xcodebuild -project "MirrorNote.xcodeproj" -scheme "MirrorNote" test
```

### Project Structure
```
MirrorNote/
├── Models/          # Data structures
├── Views/           # SwiftUI views
│   ├── Components/  # Reusable UI components
│   └── Tabs/        # Tab-specific views
├── ViewModels/      # MVVM business logic
├── Services/        # External API integrations
└── Utils/           # Helper utilities
```

## License

This project is for personal use and development learning purposes.

