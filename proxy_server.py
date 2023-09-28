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
OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]

class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def escape_invalid_json_chars(self, raw_json_str):
        return re.sub(r'\\n', r'\\\\n', raw_json_str)

    def sanitize_string(self, input_str):
        return input_str.replace('\n', '\\n').replace('\r', '\\r').replace('"', '\\"')

    def sanitize_dict(self, d):
        new_dict = {}
        for k, v in d.items():
            if isinstance(v, str):
                new_dict[k] = self.sanitize_string(v)
            else:
                new_dict[k] = v
        return new_dict


    def do_POST(self):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            chat_log = post_data.decode('utf-8')
            system_message = """You are a helpful assistant who is speaking to us using ChatGPTiger,"
                             an application developed for computers running Mac OS X 10.4 Tiger. You do not
                             need to preface your response with 'ChatGPT'."""

            # Construct messages to send to OpenAI
            messages = [{"role": "user", "content": chat_log},
                        {"role": "system", "content": system_message}]
            payload = {
                "model": "gpt-3.5-turbo",
                "messages": messages
            }

            print(json.dumps(payload, indent=2))
            conn = http.client.HTTPSConnection("api.openai.com")
            headers = {
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-type": "application/json"
            }
            conn.request("POST", "/v1/chat/completions", body=json.dumps(payload), headers=headers)
            response = conn.getresponse()

            # Parse the OpenAI response
            response_data = json.loads(response.read())
            print(json.dumps(response_data, indent=2))

            response_message = ""
            if "error" in response_data:
                # Send the error message to the client
                response_message = response_data["error"]["message"]
            else:
                # Send back only the assistant's message
                response_message = response_data["choices"][0]["message"]["content"]

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(response_message.encode("utf-8"))

        except json.JSONDecodeError as e:
            print(f"JSONDecodeError at position {e.pos}: {e}")
        except Exception as general_exception:
            print(f"An unknown error occurred: {general_exception}")

if __name__ == '__main__':
    httpd = http.server.HTTPServer((HOST_NAME, PORT_NUMBER), ProxyHTTPRequestHandler)
    print("Server started on", HOST_NAME, "at port", PORT_NUMBER)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
