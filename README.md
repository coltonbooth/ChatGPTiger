# ChatGPTiger 🐯

**Bring the power of AI to your retro Mac.**

ChatGPTiger is a native Mac OS X 10.4 (Tiger) application that bridges the gap between 2005 hardware and the modern AI era. It allows your PowerPC or Intel Mac running Tiger to communicate seamlessly with OpenAI's GPT-3.5-turbo model.

---

## ✨ Features

*   **🤖 Full GPT-3.5 Support:** Ask questions, write code, or just chat.
*   **💬 iChat-Style Bubbles:** A beautiful, retro-authentic UI powered by WebKit, featuring classic blue/grey speech bubbles.
*   **🗣️ Speech Synthesis:** ChatGPTiger speaks back! Uses the native Mac OS X text-to-speech engine to read responses aloud.
*   **📜 Context Aware:** Remembers your conversation history for coherent follow-up questions.
*   **💾 Save Chats:** Export your conversations to a text file via `File -> Save` for posterity.
*   **🔌 Universal Binary:** Runs natively on both PowerPC (G3/G4/G5) and Intel Macs.

## 🛠️ The Challenge (Why this exists)

Mac OS X 10.4 was released years before modern security standards like TLS 1.2/1.3 were defined. As a result, older Macs cannot natively establish secure HTTPS connections to modern APIs like OpenAI.

**The Solution:**
ChatGPTiger uses a "Man-in-the-Middle" proxy architecture:
1.  **The App:** A lightweight Objective-C Cocoa app running on your vintage Mac. It sends standard HTTP requests to a local proxy.
2.  **The Proxy:** A simple Python script running on a modern machine (or a highly upgraded vintage one) that handles the secure SSL handshake with OpenAI.

## 🚀 Getting Started

### Prerequisites

1.  **A Vintage Mac:** Running Mac OS X 10.4 Tiger.
2.  **A Modern Machine:** To run the proxy server (Linux, macOS, Windows, or even a Raspberry Pi).
3.  **OpenAI API Key:** You need a valid key from [platform.openai.com](https://platform.openai.com).

### Step 1: Set up the Proxy (Modern Machine)

The proxy server acts as the gateway. You need Python 3 installed.

1.  Download `proxy_server.py` from this repository.
2.  Open your terminal.
3.  Export your API key and run the server:

```bash
# Set your API Key
export OPENAI_API_KEY="sk-your-actual-api-key-here"

# Start the server
python3 proxy_server.py
```

*The server will print its local IP address (e.g., `192.168.1.50`). Note this down.*

### Step 2: Run the App (Vintage Mac)

1.  **Download:** Get the latest release (Universal Binary) or build it yourself using Xcode 2.5.
2.  **Launch:** Open `ChatGPTiger.app`.
3.  **Connect:**
    *   In the "Proxy Server" field, enter the IP address and port of your modern machine (e.g., `192.168.1.50:8080`).
    *   If you are lucky enough to run the proxy on the same machine (via TigerBrew), you can try `127.0.0.1:8080`.
4.  **Chat:** Type a message and hit "Send".

## 🏗️ Building from Source

To build this project, you need a period-accurate development environment.

*   **IDE:** Xcode 2.5
*   **OS:** Mac OS X 10.4 or 10.5 (with 10.4 SDK installed).
*   **SDK:** Mac OS X 10.4u SDK (Universal).

Open `ChatGPTiger.xcodeproj` and hit Build.

## 📝 License

This project is licensed under the **Apache 2.0 License**.

## 🤝 Contributing

Love retro computing?
1.  Fork the repo.
2.  Create a feature branch.
3.  Submit a Pull Request.

---

*Made with ❤️ for the PowerPC community.*