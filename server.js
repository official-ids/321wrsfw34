const express = require('express');
const http = require('http');
const { ExpressPeerServer } = require('peer');

const app = express();
const server = http.createServer(app);

// Порт Render.com выдает автоматически в переменную окружения PORT
const PORT = process.env.PORT || 8080;

const peerServer = ExpressPeerServer(server, {
  path: '/',
  allow_discovery: false
});

app.use('/myapp', peerServer);

// Добавим простой маршрут для проверки работоспособности (Health Check)
app.get('/', (req, res) => res.send('Сигнальный сервер PeerJS работает!'));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Сервер запущен на порту ${PORT}`);
});
