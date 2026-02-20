# AI Integration Plan - Project Columbus
*Location Intelligence & Social Discovery System*

## 🎯 Vision Statement
Build an AI-powered location intelligence system that allows users to ask natural language questions about their friends' location history, trip data, and neighborhood preferences. The AI will provide contextual answers while respecting all privacy controls and displaying results on an interactive map interface.

## 🧠 Core Capabilities Target

### Natural Language Queries
- **Friend Location History**: "Where has my friend Sarah gone recently and what neighborhood was it?"
- **Trip Analysis**: "On her last trip, can you show me all of her favorite restaurants from her last trip?"
- **Social Recommendations**: "What are good beaches that all of my friends like?"
- **Neighborhood Intelligence**: "What neighborhoods do my friends love in SF?"
- **Activity Insights**: "Who in my network has been to this restaurant?"

### AI Response Features
- Intelligent aggregation across friends' data
- Privacy-aware filtering based on friend permissions
- Map visualization with location highlighting
- Actionable insights with ratings and reviews
- Trip and neighborhood analysis with averages

## 🏗 System Architecture

### Frontend Layer (SwiftUI)
```
FindFriendsView
├── AI Glass Overlay (top 50% of screen)
│   ├── AI Chat Interface
│   ├── Message History
│   └── Typing Indicators
├── Interactive Map (bottom 50%)
│   ├── Friend Location Pins
│   ├── AI Highlighted Results
│   └── Social Context Overlays
└── AI Search Bar (replaces current search)
    ├── Natural language input
    ├── Voice integration
    └── Quick suggestions
```

### AI Processing Layer
```
AI Agent System
├── Query Parser (intent recognition)
├── Context Builder (data aggregation)
├── Privacy Engine (permission filtering)
├── Response Generator (natural language)
└── Map Coordinator (location highlighting)
```

### Data Context APIs
```
Supabase AI Functions
├── getFriendLocationIntelligence()
├── analyzeTrips()
├── getNeighborhoodPreferences()
├── getFriendActivityNearLocation()
├── getLocationSocialContext()
└── applyPrivacyFiltering()
```

## 📋 Implementation Phases

### Phase 1: AI Backend Functions & Privacy Controls
**Status**: Pending  
**Duration**: 1-2 weeks

#### New Supabase Functions
```swift
extension SupabaseManager {
    /// Get comprehensive friend location intelligence for AI context
    func getFriendLocationIntelligence(for userId: String, query: String) async -> AILocationContext
    
    /// Privacy-aware trip analysis
    func analyzeTrips(for friendIds: [String], location: String? = nil) async -> [TripAnalysis]
    
    /// Neighborhood preference analysis  
    func getNeighborhoodPreferences(for friendIds: [String]) async -> [NeighborhoodInsight]
    
    /// Get pins near location with friend context
    func getPinsNearLocation(latitude: Double, longitude: Double, radius: Double) async -> [Pin]
    
    /// Get friend activity near location with time filtering
    func getFriendActivityNearLocation(latitude: Double, longitude: Double, radius: Double, since: Date) async -> [FriendActivity]
    
    /// Get comprehensive social context for a location
    func getLocationSocialContext(latitude: Double, longitude: Double, radius: Double) async -> LocationSocialContext
}
```

#### Privacy Engine Implementation
```swift
class AIPrivacyEngine {
    func filterDataForAI(data: AILocationContext, requestingUserId: String) async -> AILocationContext
    func filterFriendsByPrivacy(_ friends: [AppUser], viewerId: String) async -> [AppUser]
    func applyLocationAccuracy(_ pins: [Pin], viewerId: String) async -> [Pin]
    func checkFriendGroupPermissions(friendId: String, viewerId: String) async -> Bool
}
```

### Phase 2: Core AI Agent Implementation  
**Status**: Pending
**Duration**: 2-3 weeks

#### AI Data Models
```swift
struct AILocationContext {
    let friends: [AppUser]
    let locationHistory: [LocationHistoryEntry] 
    let trips: [TripData]
    let favoriteSpots: [Pin]
    let recentActivity: [FriendActivity]
    let neighborhoodInsights: [NeighborhoodInsight]
}

struct AIMessage {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let highlightedLocations: [CLLocationCoordinate2D]
    let relatedFriends: [AppUser]
    let actionableData: AIActionableData?
}

enum QueryIntent {
    case friendLocationHistory(friendName: String)
    case tripAnalysis(friendName: String?, location: String?)
    case neighborhoodRecommendations(type: String?)
    case friendPreferences(category: String?)
    case locationSocialContext(coordinate: CLLocationCoordinate2D)
}
```

#### AI Agent Class
```swift
class AILocationAgent: ObservableObject {
    @Published var isProcessing = false
    @Published var conversationHistory: [AIMessage] = []
    
    func processQuery(_ query: String, context: AILocationContext) async -> AIMessage
    func parseQueryIntent(_ query: String) -> QueryIntent
    func handleFriendLocationQuery(_ intent: QueryIntent, context: AILocationContext) async -> AIMessage
    func handleTripAnalysisQuery(_ intent: QueryIntent, context: AILocationContext) async -> AIMessage
    func handleNeighborhoodQuery(_ intent: QueryIntent, context: AILocationContext) async -> AIMessage
    func generateNaturalLanguageResponse(from data: Any, for intent: QueryIntent) -> String
}
```

### Phase 3: Glass Overlay UI Implementation
**Status**: Pending
**Duration**: 1-2 weeks

#### Updated FindFriendsView
```swift
struct FindFriendsView: View {
    // Existing properties...
    @State private var showAIChat = false
    @State private var aiAgent = AILocationAgent()
    @State private var aiQuery = ""
    @State private var aiHighlightedLocations: [CLLocationCoordinate2D] = []
    @State private var currentAIContext: AILocationContext?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Existing map with AI highlighting
                Map(position: $cameraPosition) {
                    // Existing friend annotations...
                    
                    // AI highlighted locations
                    ForEach(aiHighlightedLocations.indices, id: \.self) { index in
                        let coord = aiHighlightedLocations[index]
                        Annotation("AI Result", coordinate: coord) {
                            AILocationMarker()
                        }
                    }
                }
                
                // AI Glass Overlay
                if showAIChat {
                    VStack {
                        AIGlassOverlay(
                            agent: aiAgent,
                            query: $aiQuery,
                            onLocationHighlight: highlightLocationOnMap,
                            onFriendSelect: selectFriendOnMap
                        )
                        .frame(height: UIScreen.main.bounds.height * 0.5)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // AI Search Bar (bottom)
                VStack {
                    Spacer()
                    AISearchInterface(
                        query: $aiQuery,
                        isActive: $showAIChat,
                        onSubmit: handleAIQuery
                    )
                }
            }
        }
    }
    
    private func handleAIQuery(_ query: String) async {
        // Load AI context
        guard let userId = authManager.currentUserID else { return }
        let context = await loadAIContext(for: userId)
        
        // Process with AI agent
        let response = await aiAgent.processQuery(query, context: context)
        
        // Update UI
        await MainActor.run {
            aiHighlightedLocations = response.highlightedLocations
            // Update map camera if needed
        }
    }
}
```

#### Glass Overlay Components
```swift
struct AIGlassOverlay: View {
    @ObservedObject var agent: AILocationAgent
    @Binding var query: String
    let onLocationHighlight: ([CLLocationCoordinate2D]) -> Void
    let onFriendSelect: (AppUser) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(agent.conversationHistory) { message in
                            AIMessageBubble(
                                message: message,
                                onLocationTap: onLocationHighlight,
                                onFriendTap: onFriendSelect
                            )
                        }
                        
                        if agent.isProcessing {
                            AITypingIndicator()
                        }
                    }
                    .padding()
                }
            }
            
            // Input Bar
            AIInputBar(query: $query, agent: agent)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct AIMessageBubble: View {
    let message: AIMessage
    let onLocationTap: ([CLLocationCoordinate2D]) -> Void
    let onFriendTap: (AppUser) -> Void
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(message.content)
                    .padding()
                    .background(message.isFromUser ? .blue : .gray.opacity(0.2))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)
                
                // Interactive elements
                if !message.highlightedLocations.isEmpty {
                    Button("Show \(message.highlightedLocations.count) locations on map") {
                        onLocationTap(message.highlightedLocations)
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal)
                }
                
                // Friend avatars
                if !message.relatedFriends.isEmpty {
                    HStack(spacing: -5) {
                        ForEach(message.relatedFriends.prefix(5)) { friend in
                            Button(action: { onFriendTap(friend) }) {
                                AsyncImage(url: URL(string: friend.avatarURL ?? "")) { image in
                                    image.resizable()
                                } placeholder: {
                                    Circle().fill(.gray.opacity(0.3))
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 1))
                            }
                        }
                        
                        if message.relatedFriends.count > 5 {
                            Text("+\(message.relatedFriends.count - 5)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !message.isFromUser { Spacer() }
        }
    }
}
```

### Phase 4: Advanced Query Processing
**Status**: Pending
**Duration**: 2-3 weeks

#### Query Intent Recognition
```swift
extension AILocationAgent {
    private func parseQueryIntent(_ query: String) -> QueryIntent {
        let lowercased = query.lowercased()
        
        // Friend location history patterns
        if lowercased.contains("where has") && lowercased.contains("been") {
            let friendName = extractFriendName(from: query)
            return .friendLocationHistory(friendName: friendName)
        }
        
        // Trip analysis patterns
        if lowercased.contains("trip") || lowercased.contains("vacation") {
            let friendName = extractFriendName(from: query)
            let location = extractLocation(from: query)
            return .tripAnalysis(friendName: friendName, location: location)
        }
        
        // Neighborhood recommendations
        if lowercased.contains("neighborhood") || lowercased.contains("area") {
            let type = extractPlaceType(from: query)
            return .neighborhoodRecommendations(type: type)
        }
        
        // Default to general preferences
        let category = extractCategory(from: query)
        return .friendPreferences(category: category)
    }
    
    private func extractFriendName(from query: String) -> String {
        // Implementation to extract friend names from natural language
        // Could use regex patterns or NLP libraries
    }
}
```

#### Response Generation Examples
```swift
// Example AI Responses:

// Query: "Where has Sarah been recently?"
// Response: 
"""
Sarah has been active in 3 neighborhoods recently:

🌉 **Mission District, SF** (3 visits last week)
- Visited Tartine Bakery, rated 5⭐ 
- Went to Dolores Park twice
- Average stay: 2.5 hours

📍 **Hayes Valley** (2 visits)
- Blue Bottle Coffee on Monday
- Patricia's Green Park  

🏙️ **SOMA** (1 visit)
- Moscone Center area

Tap to see these locations on the map!
"""

// Query: "What beaches do my friends love?"
// Response:
"""
Based on your friends' activity, here are their top-rated beaches:

🏖️ **Ocean Beach** - Average 4.2⭐ from 8 friends
- Emma: "Perfect for sunset walks"
- Jake: "Great surf spot!"
- 12 total visits this year

🏖️ **Baker Beach** - Average 4.7⭐ from 5 friends
- Sarah: "Amazing Golden Gate views" 
- Alex: "Hidden gem for photography"
- Best visited: Late afternoon

🌊 **Half Moon Bay** - Average 4.0⭐ from 4 friends
- Popular for weekend trips
- Mike's favorite spot for tide pooling

Would you like me to show you the best times to visit each beach?
"""
```

### Phase 5: Privacy & Permissions Integration
**Status**: Pending
**Duration**: 1 week

#### Privacy Controls
```swift
// New privacy settings for AI features
struct AIPrivacySettings {
    var allowLocationIntelligence: Bool = false
    var allowTripAnalysis: Bool = false
    var allowNeighborhoodSharing: Bool = true
    var allowActivitySharing: Bool = true
    var maxHistoryDays: Int = 30
    var friendGroupsWithAIAccess: [UUID] = []
}

// Integration with existing privacy system
extension LocationPrivacySettings {
    var aiPrivacySettings: AIPrivacySettings {
        return AIPrivacySettings(
            allowLocationIntelligence: shareLocationWithFriends,
            allowTripAnalysis: shareLocationHistory,
            allowNeighborhoodSharing: shareLocationWithFriends,
            allowActivitySharing: shareLocationWithFriends && shareLocationHistory
        )
    }
}
```

#### Privacy UI Integration
```swift
// Add to LocationPrivacySettingsView
Section("AI Intelligence") {
    Toggle("Allow AI Location Analysis", isOn: $allowAIAnalysis)
        .help("Let AI analyze your location data to answer friends' questions")
    
    Toggle("Share Trip Insights", isOn: $allowTripSharing)
        .help("Allow AI to share insights about your trips with friends")
    
    Picker("History Scope", selection: $aiHistoryDays) {
        Text("7 days").tag(7)
        Text("30 days").tag(30)  
        Text("90 days").tag(90)
    }
}
```

### Phase 6: Map Integration & Visualization
**Status**: Pending
**Duration**: 1 week

#### Enhanced Map Annotations
```swift
struct AILocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.purple.opacity(0.7))
                .frame(width: 20, height: 20)
            
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 20, height: 20)
            
            Image(systemName: "brain.fill")
                .font(.system(size: 8))
                .foregroundColor(.white)
        }
        .shadow(radius: 3)
    }
}

struct AILocationCluster: View {
    let locations: [CLLocationCoordinate2D]
    let friendCount: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.purple.gradient)
                .frame(width: 30, height: 30)
            
            Text("\(friendCount)")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .shadow(radius: 5)
        .scaleEffect(1.2)
    }
}
```

## 🔐 Privacy Architecture

### Data Access Levels
1. **Public**: Anyone can see (shareLocationPublicly = true)
2. **Friends**: Mutual followers only (shareLocationWithFriends = true)
3. **Followers**: One-way followers (shareLocationWithFollowers = true)  
4. **Private**: Owner only (all sharing disabled)

### AI-Specific Privacy Controls
- **Location Intelligence Toggle**: Master switch for AI features
- **Trip Analysis Permission**: Allow/block trip-based insights
- **History Scope**: Limit AI data to recent timeframes
- **Friend Group Filtering**: Only analyze data from specific friend groups

### Privacy Filtering Pipeline
```
User Query → Privacy Engine → Friend Permission Check → Location Accuracy Filter → AI Context → Response
```

## 🚀 Future Enhancements

### Phase 7: Advanced Intelligence (Future)
- **Predictive Recommendations**: "Your friends usually love Japanese food in this neighborhood"
- **Event Intelligence**: "3 friends are planning to visit this area next week"  
- **Seasonal Insights**: "Your friends rated this place higher in summer"
- **Photo Integration**: AI analysis of shared photos for location context

### Phase 8: Voice Integration (Future)
- Natural voice queries through existing speech recognition
- Voice responses with map navigation
- Hands-free location intelligence while driving

### Phase 9: Collaborative Intelligence (Future)
- Group trip planning with AI recommendations
- Shared preference learning across friend groups
- Community location intelligence beyond just friends

## 📊 Success Metrics

### Technical Metrics
- Query response time < 2 seconds
- Privacy filtering accuracy 100%
- Map visualization performance 60fps
- AI context relevance score > 85%

### User Experience Metrics  
- Query success rate (user gets useful answer)
- Feature adoption rate
- Privacy comfort score (user surveys)
- Time spent in AI interface vs traditional search

## 🔄 Update Log
- **Initial Plan Created**: [Current Date]
- **Next Review**: [Schedule regular updates]

---

*This document will be updated as implementation progresses and requirements evolve. All team members should reference this for the latest AI integration specifications.* 