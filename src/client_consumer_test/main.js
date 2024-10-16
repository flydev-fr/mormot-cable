import './style.css';

let PSEUDO = '';
let client = null;

class WebSocketClient {
    constructor(url, pseudo) {
        this.url = url;
        this.pseudo = pseudo; // Store the pseudonym
        this.webSocket = null;
        this.channels = {};
        this.connected = false;
    }

    // Establish a WebSocket connection
    connect() {
        this.webSocket = new WebSocket(this.url);

        this.webSocket.onopen = () => {
            console.log('WebSocket connection established');
            this.connected = true;
            this.resubscribeChannels();
        };

        this.webSocket.onmessage = (event) => {
            this.handleMessage(event.data);
        };

        this.webSocket.onclose = () => {
            console.log('WebSocket connection closed');
            this.connected = false;
        };

        this.webSocket.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }

    // Handle incoming messages
    handleMessage(message) {
        const data = JSON.parse(message);
        const { FromUserName, MsgData } = data; // Extract the message content

        const channel = 'ChatChannel'; // Assuming a single channel

        // Invoke the callback associated with the channel
        if (this.channels[channel]) {
            this.channels[channel](FromUserName + ': ' + MsgData);
        }
    }

    // Subscribe to a channel with a callback function
    subscribe(channelName, receiveCallback) {
        this.channels[channelName] = receiveCallback;

        if (this.connected) {
            // Send a subscription command to the server
            this.webSocket.send(JSON.stringify({
                command: 'subscribe',
                channel: channelName,
                user: this.pseudo
            }));
        }
    }

    // Unsubscribe from a channel
    unsubscribe(channelName) {
        if (this.channels[channelName]) {
            delete this.channels[channelName];

            if (this.connected) {
                this.webSocket.send(JSON.stringify({
                    command: 'unsubscribe',
                    channel: channelName,
                    user: this.pseudo
                }));
            }
        }
    }

    // Send a message to the server
    perform(channelName, data) {
        if (this.connected) {
            this.webSocket.send(JSON.stringify({
                command: 'message',
                channel: channelName,
                user: this.pseudo,
                message: data.message
            }));
        }
    }

    // Resubscribe to all channels after reconnecting
    resubscribeChannels() {
        for (const channel in this.channels) {
            this.webSocket.send(JSON.stringify({
                command: 'subscribe',
                user: this.pseudo,
                channel,
            }));
        }
    }
}

document.getElementById('connectButton').addEventListener('click', () => {
    const pseudoInput = document.getElementById('pseudoInput');
    PSEUDO = pseudoInput.value.trim();

    if (PSEUDO !== '') {
        pseudoInput.disabled = true;
        document.getElementById('connectButton').disabled = true;

        client = new WebSocketClient('ws://192.168.1.6:8082/cable', PSEUDO);

        client.connect();

        client.subscribe('ChatChannel', (content) => {
            console.log('Received content:', content);
            const contentTextArea = document.getElementById('content');
            contentTextArea.value += content + '\n'; // Append the new message
            contentTextArea.scrollTop = contentTextArea.scrollHeight; // Scroll to the bottom
        });
    } else {
        alert('Please enter a pseudonym before connecting.');
    }
});

document.getElementById('sendButton').addEventListener('click', () => {
    if (client && client.connected) {
        const messageInput = document.getElementById('messageInput');
        const message = messageInput.value.trim();
        if (message !== '') {
            messageInput.value = '';
            client.perform('ChatChannel', { message });
        }
    } else {
        alert('You must connect first before sending messages.');
    }
});