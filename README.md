# 🕐 Talk Time - Voice Clock for the Visually Impaired

<p align="center">
  <img src="screenshots/icon.png" alt="Talk Time Logo" width="200"/>
</p>

<p align="center">
  <strong>A voice-based clock assistant designed for blind and visually impaired users</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#license">License</a>
</p>

---

## 📱 About

**Talk Time** is a smartphone application that helps blind and visually impaired people know the time without needing extra help. Simply tap anywhere on the screen to hear the current time spoken aloud, or set automatic announcements at regular intervals.

This app was created with accessibility as the primary focus, featuring:
- Large touch areas for easy interaction
- High contrast design
- Full voice feedback
- Works 24/7 in the background

## ✨ Features

- **🎯 Tap to Hear** - Touch anywhere on the screen to hear the current time
- **⏰ Auto Announcements** - Set automatic time announcements every 15, 30, or 60 minutes
- **🌙 Quiet Hours** - Disable announcements during sleeping hours (e.g., 10 PM - 7 AM)
- **🔔 Background Operation** - Works even when the app is minimized or closed
- **🎨 Beautiful Clock** - Analog wall clock with digital display
- **📳 Haptic Feedback** - Feel a vibration when time is spoken
- **🌐 Multi-Language** - Support for multiple languages
- **🔋 Battery Efficient** - Optimized for low battery consumption
- **🔊 Adjustable Voice** - Control volume and speech speed

## 🚀 Installation

### Download APK
Download the latest APK from the [Releases](https://github.com/abel2800/Time-Talk/releases) page.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/abel2800/Time-Talk.git

# Navigate to project directory
cd Time-Talk

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release
```

## 📖 Usage

1. **Open the app** - Grant permissions when prompted for background operation
2. **Tap anywhere** - Touch the screen to hear the current time
3. **Set intervals** - Go to Settings → Auto Announcements → Select interval
4. **Quiet hours** - Enable quiet hours to pause announcements at night
5. **Background mode** - The app continues announcing time even when minimized

### First Time Setup
When you first open the app, you'll be asked to:
1. Allow notification permissions
2. Disable battery optimization (for 24/7 operation)

This ensures the app can announce the time even when running in the background.

## 🛠️ Built With

- [Flutter](https://flutter.dev/) - Cross-platform framework
- [flutter_tts](https://pub.dev/packages/flutter_tts) - Text-to-Speech
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) - Background notifications
- [permission_handler](https://pub.dev/packages/permission_handler) - Permission management
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage

## 🤝 Contributing

Contributions are welcome! If you have ideas to make this app more accessible, please:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Copyright (c) 2024 Abel**

## 👤 Author

**Abel**
- GitHub: [@abel2800](https://github.com/abel2800)

## 🙏 Acknowledgments

- Designed with love for the visually impaired community
- Inspired by the need for accessible technology
- Thanks to all who provided feedback and suggestions

---

<p align="center">
  Made with ❤️ for accessibility
</p>
