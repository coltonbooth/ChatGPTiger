import http.server
import http.client
import socket
import json
import os
import re

# --- Configuration ---

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.254.254.254', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '0.0.0.0'
    finally:
        s.close()
    return local_ip

HOST_NAME = get_local_ip()
PORT_NUMBER = 8080

# API Keys
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# Default State
CURRENT_PROVIDER = "openai" # openai, anthropic, gemini
CURRENT_MODEL = "gpt-4o-mini" # Default start model

# --- Provider Logic ---

def call_openai(messages, model):
    if not OPENAI_API_KEY:
        return "Error: OPENAI_API_KEY is not set."

    # OpenAI expects "system", "user", "assistant"
    payload = {
        "model": model,
        "messages": messages
    }
    
    print(f"Calling OpenAI ({model})...")
    conn = http.client.HTTPSConnection("api.openai.com")
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-type": "application/json"
    }
    conn.request("POST", "/v1/chat/completions", body=json.dumps(payload), headers=headers)
    response = conn.getresponse()
    data = json.loads(response.read())
    
    if "error" in data:
        return f"OpenAI Error: {data['error']['message']}"
    return data["choices"][0]["message"]["content"]

def call_anthropic(messages, model):
    if not ANTHROPIC_API_KEY:
        return "Error: ANTHROPIC_API_KEY is not set."

    # Anthropic separates 'system' from 'messages'
    system_prompt = ""
    filtered_messages = []
    for msg in messages:
        if msg["role"] == "system":
            system_prompt = msg["content"]
        else:
            filtered_messages.append(msg)

    payload = {
        "model": model,
        "max_tokens": 4096,
        "messages": filtered_messages
    }
    if system_prompt:
        payload["system"] = system_prompt

    print(f"Calling Anthropic ({model})...")
    conn = http.client.HTTPSConnection("api.anthropic.com")
    headers = {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    conn.request("POST", "/v1/messages", body=json.dumps(payload), headers=headers)
    response = conn.getresponse()
    data = json.loads(response.read())

    if "error" in data:
        return f"Anthropic Error: {data['error']['message']}"
    return data["content"][0]["text"]

def call_gemini(messages, model):
    if not GEMINI_API_KEY:
        return "Error: GEMINI_API_KEY is not set."

    # Gemini uses "user" and "model" roles. System instructions are separate config (v1beta).
    # Simple mapping: system -> user (prepend), assistant -> model
    
    gemini_contents = []
    system_instruction = None

    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        
        if role == "system":
             # For simplicity in this basic proxy, we'll prepend system prompt to first user message 
             # or use system_instruction if using the very latest API, but prepending is safer for compatibility.
             # Actually, let's just make it a user message at the start for now to ensure it works.
             pass 
        elif role == "user":
            gemini_contents.append({"role": "user", "parts": [{"text": content}]})
        elif role == "assistant":
            gemini_contents.append({"role": "model", "parts": [{"text": content}]})

    # Add system prompt to the beginning if it exists
    system_content = next((m["content"] for m in messages if m["role"] == "system"), None)
    if system_content:
        # Gemini 1.5 allows system instructions, but via a different field. 
        # We will keep it simple: Prepend to history or 'user'
        # If the first message is user, prepend.
        if gemini_contents and gemini_contents[0]["role"] == "user":
            gemini_contents[0]["parts"][0]["text"] = f"System: {system_content}\n\n" + gemini_contents[0]["parts"][0]["text"]
        else:
            gemini_contents.insert(0, {"role": "user", "parts": [{"text": f"System Instruction: {system_content}"}]})

    payload = {
        "contents": gemini_contents
    }

    print(f"Calling Gemini ({model})...")
    conn = http.client.HTTPSConnection("generativelanguage.googleapis.com")
    headers = {"Content-type": "application/json"}
    
    path = f"/v1beta/models/{model}:generateContent?key={GEMINI_API_KEY}"
    conn.request("POST", path, body=json.dumps(payload), headers=headers)
    response = conn.getresponse()
    data = json.loads(response.read())

    if "error" in data:
        return f"Gemini Error: {data['error']['message']}"
    
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        return "Gemini Error: Unexpected response format."


# --- Handler ---

class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        global CURRENT_PROVIDER, CURRENT_MODEL
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            decoded_data = post_data.decode('utf-8')
            
            # --- Parse Input ---
            
            system_msg_content = """You are a helpful assistant speaking via ChatGPTiger on a vintage Mac OS X 10.4 computer.
            Keep responses concise. Do not use Markdown if possible, or use it sparingly as the client has limited rendering."""
            
            system_message = {"role": "system", "content": system_msg_content}
            messages = []
            
            try:
                parsed = json.loads(decoded_data)
                if isinstance(parsed, list):
                    messages = [system_message] + parsed
                else:
                    messages = [system_message, {"role": "user", "content": decoded_data}]
            except json.JSONDecodeError:
                messages = [system_message, {"role": "user", "content": decoded_data}]

            # --- Check for Slash Commands ---
            # Look at the LAST message (current user input)
            last_user_msg = messages[-1]["content"].strip()
            
            if last_user_msg.startswith("/use ") or last_user_msg.startswith("/model "):
                parts = last_user_msg.split(" ")
                command = parts[0]
                arg = parts[1] if len(parts) > 1 else ""

                response_text = ""
                
                if command == "/use":
                    if "openai" in arg.lower():
                        CURRENT_PROVIDER = "openai"
                        CURRENT_MODEL = "gpt-4o-mini"
                        response_text = "Switched to OpenAI (gpt-4o-mini)."
                    elif "claude" in arg.lower() or "anthropic" in arg.lower():
                        CURRENT_PROVIDER = "anthropic"
                        CURRENT_MODEL = "claude-3-5-sonnet-latest"
                        response_text = "Switched to Anthropic (Claude 3.5 Sonnet)."
                    elif "gemini" in arg.lower() or "google" in arg.lower():
                        CURRENT_PROVIDER = "gemini"
                        CURRENT_MODEL = "gemini-1.5-flash"
                        response_text = "Switched to Google (Gemini 1.5 Flash)."
                    else:
                        response_text = f"Unknown provider: {arg}. Available: openai, claude, gemini."
                
                elif command == "/model":
                    CURRENT_MODEL = arg
                    response_text = f"Model set to: {CURRENT_MODEL}"

                # Send system response immediately
                self.send_response(200)
                self.send_header("Content-type", "text/plain; charset=utf-8")
                self.end_headers()
                self.wfile.write(response_text.encode("utf-8"))
                return

            # --- Route to Provider ---
            
            response_content = ""
            
            if CURRENT_PROVIDER == "openai":
                response_content = call_openai(messages, CURRENT_MODEL)
            elif CURRENT_PROVIDER == "anthropic":
                response_content = call_anthropic(messages, CURRENT_MODEL)
            elif CURRENT_PROVIDER == "gemini":
                response_content = call_gemini(messages, CURRENT_MODEL)
            else:
                response_content = f"Error: Unknown provider {CURRENT_PROVIDER}"

            self.send_response(200)
            self.send_header("Content-type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(response_content.encode("utf-8"))

        except Exception as e:
            print(f"Server Error: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode("utf-8"))

if __name__ == '__main__':
    print("--- ChatGPTiger Proxy Server ---")
    print(f"Listening on {HOST_NAME}:{PORT_NUMBER}")
    print(f"Current Provider: {CURRENT_PROVIDER} ({CURRENT_MODEL})")
    print("--------------------------------")
    
    if not (OPENAI_API_KEY or ANTHROPIC_API_KEY or GEMINI_API_KEY):
        print("WARNING: No API keys found in environment variables!")
    
    httpd = http.server.HTTPServer((HOST_NAME, PORT_NUMBER), ProxyHTTPRequestHandler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
