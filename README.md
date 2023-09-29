# ChatGPTiger

ChatGPTiger is a utility that allows Mac OS X 10.4 (Tiger) computers to communicate with OpenAI's GPT-3.5-turbo model, also known as ChatGPT. This is essential because Mac OS X 10.4 was deprecated before the advent of modern SSL standards.

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [For Power Users](#for-power-users)
- [Downloads](#downloads)
- [Contributing](#contributing)
- [License](#license)

## Features
- Connects older Mac OS X 10.4 (Tiger) computers to OpenAI's GPT-3.5-turbo model
- Included `proxy_server.py` to manage SSL and API calls

## Installation

1. **Get an OpenAI API Key**: Go to the [OpenAI API site](https://platform.openai.com) to obtain your API key.
  
2. **Download ChatGPTiger**: Choose from our list of compiled binaries or source code from the download section.

3. **Proxy Server Setup**: Run the included Python proxy server on a machine capable of modern SSL.

## Usage

1. Run the proxy server by executing `OPENAI_API_KEY="YOUR API KEY HERE" python3 proxy_server.py` from the directory where `proxy_server.py` is located.

2. Open ChatGPTiger.app on your older Mac. Alternatively, build the app in Xcode if you have downloaded the source code.

3. Enter the local IP address of your proxy server into the provided field in the ChatGPTiger app.

4. You can now start chatting with ChatGPT.

## For Power Users

If you have TigerBrew installed, you can run the proxy server on your old Mac itself. Requirements are OpenSSL and Python3 installed via TigerBrew. Modifications may be required to the OpenSSL `.rb` file by adding `no-asm` to `configure_args`.

## Downloads

- [Project GitHub](https://github.com/coltonbooth/ChatGPTiger)
- [Universal Binary - Version 0.1.5](http://pickledapple.com/ChatGPTiger/ChatGPTiger-0.1.5-universal_binary.zip)
- [Source Code - Version 0.1.5](http://pickledapple.com/ChatGPTiger/ChatGPTiger-0.1.5-source.zip)
- [Proxy Server - Python Source](http://pickledapple.com/ChatGPTiger/proxy_server.zip)

## Contributing

Interested in contributing? Check out the [issues](https://github.com/coltonbooth/ChatGPTiger/issues) or make a pull request.

## License

This project is licensed under Apache 2.
