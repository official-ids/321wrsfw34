const express = require('express');
const http = require('http');
const { ExpressPeerServer } = require('peer');

const app = express();
const server = http.createServer(app);

// Порт берется из переменных окружения Fly.io (обычно 8080)
const PORT = process.env.PORT || 8080;

const peerServer = ExpressPeerServer(server, {
  path: '/',
  allow_discovery: false // Из соображений безопасности отключаем список всех пиров
});

app.use('/myapp', peerServer);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Сигнальный сервер запущен на порту ${PORT}`);
});
