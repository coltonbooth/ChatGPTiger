import http.server
import http.client
import socket
import json
import os
import re

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't need to be reachable; the OS just uses this to determine the most
        # appropriate network interface to use.
        s.connect(('10.254.254.254', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '0.0.0.0'
    finally:
        s.close()
    return local_ip

# Configuration for the proxy server
HOST_NAME = get_local_ip()
PORT_NUMBER = 8080
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")

class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            decoded_data = post_data.decode('utf-8')
            
            system_message_content = """You are a helpful assistant who is speaking to us using ChatGPTiger,
                             an application developed for computers running Mac OS X 10.4 Tiger. You do not
                             need to preface your response with 'ChatGPT'."""
            system_message = {"role": "system", "content": system_message_content}

            messages = []
            
            # Check if input is JSON (list of messages) or raw string
            try:
                parsed = json.loads(decoded_data)
                if isinstance(parsed, list):
                    messages = [system_message] + parsed
                else:
                    # JSON but not a list? Treat as content.
                    messages = [system_message, {"role": "user", "content": decoded_data}]
            except json.JSONDecodeError:
                # Raw string
                messages = [system_message, {"role": "user", "content": decoded_data}]

            payload = {
                "model": "gpt-3.5-turbo",
                "messages": messages
            }

            print("Sending payload to OpenAI:")
            print(json.dumps(payload, indent=2))
            
            if not OPENAI_API_KEY:
                raise Exception("OPENAI_API_KEY not set")

            conn = http.client.HTTPSConnection("api.openai.com")
            headers = {
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-type": "application/json"
            }
            conn.request("POST", "/v1/chat/completions", body=json.dumps(payload), headers=headers)
            response = conn.getresponse()

            response_data = json.loads(response.read())
            print("Response from OpenAI:")
            # print(json.dumps(response_data, indent=2))

            response_message = ""
            if "error" in response_data:
                response_message = f"Error: {response_data['error']['message']}"
            else:
                response_message = response_data["choices"][0]["message"]["content"]

            self.send_response(200)
            self.send_header("Content-type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(response_message.encode("utf-8"))

        except Exception as general_exception:
            print(f"An error occurred: {general_exception}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(general_exception).encode("utf-8"))

if __name__ == '__main__':
    if not OPENAI_API_KEY:
        print("WARNING: OPENAI_API_KEY is not set. Requests will fail.")
        
    httpd = http.server.HTTPServer((HOST_NAME, PORT_NUMBER), ProxyHTTPRequestHandler)
    print("Server started on", HOST_NAME, "at port", PORT_NUMBER)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()