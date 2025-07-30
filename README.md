# 🚀 ExerAI

**Your AI-Powered Fitness Companion**  
A Flutter-based mobile app backed by Firebase and integrated with Gemini LLM agents to generate personalized workout plans, track user progress, and provide exercise recommendations.

---

## 💡 Features

- **Chat with Gemini Agent**: Use Gemini’s GPT‑style models via Firebase AI to generate custom workouts, respond to health queries, and deliver exercise guidance.  
- **Workout Plan Generator**: Create personalized exercise routines based on user goals, preferences, and history using LLM-powered function calling.  
- **Session & Streak Tracking**: Monitor completed workouts, maintain progress records, and track streaks/rewards.  
- **Video Demonstrations**: Integrate Cloudflare-hosted stock videos to show proper form for exercises.  

---

## 🏗️ Tech Stack

| Layer              | Technology                                                  |
|-------------------|--------------------------------------------------------------|
| **Frontend**      | Flutter (Dart)                                               |
| **Backend & AI**  | Firebase (Firestore & Authentication, Firebase AI + Gemini |
| **Chat Agent**    | Gemini LLM with Function Calling                             |
| **Media Storage** | Cloudflare for workout video hosting                         |

---

## 🧩 Architecture Overview

```
Flutter App (UI & State) 
    ↔ Firebase Auth + Firestore (User data + chat history)
    ↔ Firebase AI Agent (wraps Gemini models)
         └─ Function calls generate workout plans based on inputs + context
Media assets (videos) served via Cloudflare
```

- Chat UI displays LLM-driven conversations  
- Function calling patterns allow structured requests/responses  
- Minimal exercise database (~45+ items), stored locally and in Firestore  

---

## 🔧 Installation

1. **Clone the repository**  
   ```bash
   git clone https://github.com/your-handle/exerai.git
   cd exerai
   ```

2. **Install dependencies**  
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**  
   - Add `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)  
   - Enable Firebase Authentication, Firestore, and Firebase GenAI

4. **Run the app**  
   ```bash
   flutter run
   ```

---

## ⚠️ Limitations & Challenges

- **Flutter learning curve**: UI setup and state management require experience  
- **Limited exercise database**: Currently around 45 exercises included  
- **Prompt engineering**: Output format inconsistency can occur with LLMs  

---

## 🏆 Achievements

- Built a conversational UI powered by Gemini LLM  
- Implemented structured function calling for workout generation  
- Created a tracking system for sessions, streaks, and history  

---

## 🚀 Roadmap

- 🧍‍♀️ Pose detection for form correction (ML Kit / Posenet)  
- 🎧 Voice-based assistant and workout narration  
- 📊 Personal analytics dashboard with workout history  
- 🥗 AI-powered diet/nutrition recommendations  
- 🏋️ More exercises, tags, categories, and difficulty levels  

---

## 🛠️ Built With

- [Flutter](https://flutter.dev/) — Cross-platform UI framework  
- [Firebase](https://firebase.google.com/) — Backend services (Auth, Firestore, AI)  
- [Gemini](https://ai.google.dev/) — LLM for workout planning  
- [Cloudflare](https://www.cloudflare.com/) — Static media hosting for exercise videos  

---

## 👤 Contributors

- **Aman Negi** — Developer, Gemini Agent Integration, Firebase Setup, UI/UX
  
## Articles

- [ ExerAI: An AI-Powered Fitness Recommendation Application ](https://amannegi.online/exerai-an-ai-powered-fitness-recommendation-application)  

---
