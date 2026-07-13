--[[
	================================================================================
	🍎 APPLE GLASSMORPHISM CHAT SYSTEM — ULTIMATE EDITION
	================================================================================
	Версия:       3.0.0
	Автор:        Chat Systems Studio
	Дата:         2026
	Описание:     Полноценная система кастомизации чата Roblox с поддержкой тем,
	              команд, эмодзи, упоминаний, фильтров, истории, статистики,
	              анимаций, эффектов, уведомлений и многого другого.
	================================================================================
	📋 ВОЗМОЖНОСТИ:
	  • 12 готовых тем оформления (Apple, Cyberpunk, Sunset, Ocean, Forest, Neon,
	    Midnight, Rose Gold, Matrix, Aurora, Mono, Candy)
	  • 25+ команд чата (/help, /theme, /clear, /size, /color, /blur, ...)
	  • Система эмодзи с автозаменой текста на изображения
	  • Система упоминаний @username с подсветкой
	  • Фильтр нежелательных слов с настраиваемым словарём
	  • История сообщений с поиском и экспортом
	  • Статистика активности (счётчики, графики)
	  • Плавные анимации и визуальные эффекты
	  • Звуковые уведомления
	  • Сохранение/загрузка настроек в DataStore
	  • Модульная архитектура с обработкой ошибок
	================================================================================
]]

--------------------------------------------------------------------------------
-- 🔧 СЕКЦИЯ 1: ПОДКЛЮЧЕНИЕ СЕРВИСОВ И БАЗОВЫЕ ПЕРЕМЕННЫЕ
--------------------------------------------------------------------------------
local TextChatService = game:GetService("TextChatService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local player            = Players.LocalPlayer
local playerGui         = player:WaitForChild("PlayerGui")

-- Глобальная таблица системы
local ChatSystem        = {}
ChatSystem.Version      = "3.0.0"
ChatSystem.Modules      = {}
ChatSystem.State        = {}
ChatSystem.Cache        = {}
ChatSystem.Hooks        = {}

--------------------------------------------------------------------------------
-- 🧰 СЕКЦИЯ 2: МОДУЛЬ УТИЛИТ (UTILITIES)
--------------------------------------------------------------------------------
local Utils = {}

-- Генерация уникального ID
function Utils.generateId(prefix)
	prefix = prefix or "id"
	return string.format("%s_%s_%d", prefix,
		tostring(math.random(1000, 9999)),
		os.clock() * 1000 % 10000)
end

-- Безопасное выполнение с обработкой ошибок
function Utils.safeCall(func, ...)
	local success, result = pcall(func, ...)
	if not success then
		warn("[ChatSystem] Ошибка:", result)
		return nil, result
	end
	return result
end

-- Глубокое копирование таблицы
function Utils.deepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[Utils.deepCopy(key)] = Utils.deepCopy(value)
	end
	return setmetatable(copy, getmetatable(original))
end

-- Слияние двух таблиц
function Utils.mergeTables(base, override)
	local result = Utils.deepCopy(base)
	for key, value in pairs(override or {}) do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = Utils.mergeTables(result[key], value)
		else
			result[key] = value
		end
	end
	return result
end

-- Форматирование времени (HH:MM:SS)
function Utils.formatTime(timestamp)
	timestamp = timestamp or os.time()
	return os.date("%H:%M:%S", timestamp)
end

-- Форматирование даты
function Utils.formatDate(timestamp)
	timestamp = timestamp or os.time()
	return os.date("%Y-%m-%d", timestamp)
end

-- Обрезка строки с многоточием
function Utils.truncate(str, maxLen)
	maxLen = maxLen or 50
	if #str <= maxLen then return str end
	return string.sub(str, 1, maxLen - 3) .. "..."
end

-- Проверка, является ли значение числом
function Utils.isNumber(value)
	return type(value) == "number" and value == value
end

-- Ограничение значения в диапазоне
function Utils.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

-- Линейная интерполяция
function Utils.lerp(a, b, t)
	return a + (b - a) * t
end

-- Плавная интерполяция цвета
function Utils.lerpColor(c1, c2, t)
	return Color3.new(
		Utils.lerp(c1.R, c2.R, t),
		Utils.lerp(c1.G, c2.G, t),
		Utils.lerp(c1.B, c2.B, t)
	)
end

-- Преобразование Color3 в HEX
function Utils.colorToHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255))
end

-- Преобразование HEX в Color3
function Utils.hexToColor(hex)
	hex = hex:gsub("#", "")
	if #hex ~= 6 then return Color3.new(1, 1, 1) end
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255
	return Color3.new(r, g, b)
end

-- Разбиение строки по разделителю
function Utils.split(str, delimiter)
	delimiter = delimiter or " "
	local result = {}
	for part in string.gmatch(str, "([^" .. delimiter .. "]+)") do
		table.insert(result, part)
	end
	return result
end

-- Удаление пробелов по краям
function Utils.trim(str)
	return str:match("^%s*(.-)%s*$")
end

-- Проверка вхождения подстроки
function Utils.contains(str, sub)
	return string.find(string.lower(str), string.lower(sub)) ~= nil
end

-- Задержка с возможностью отмены
function Utils.delayed(seconds, callback)
	task.delay(seconds, function()
		Utils.safeCall(callback)
	end)
end

-- Создание простого Tween
function Utils.tween(instance, time, properties, style, direction)
	style = style or Enum.EasingStyle.Quad
	direction = direction or Enum.EasingDirection.Out
	local info = TweenInfo.new(time, style, direction)
	local tween = TweenService:Create(instance, info, properties)
	tween:Play()
	return tween
end

-- Логирование с уровнем
function Utils.log(level, message, data)
	local prefix = string.format("[%s][%s]", level, Utils.formatTime())
	if data then
		print(prefix, message, data)
	else
		print(prefix, message)
	end
end

function Utils.info(message, data)  Utils.log("INFO",  message, data) end
function Utils.warn(message, data)  Utils.log("WARN",  message, data) end
function Utils.error(message, data) Utils.log("ERROR", message, data) end
function Utils.debug(message, data) Utils.log("DEBUG", message, data) end

ChatSystem.Utils = Utils

--------------------------------------------------------------------------------
-- ⚙️ СЕКЦИЯ 3: МОДУЛЬ КОНФИГУРАЦИИ (CONFIG)
--------------------------------------------------------------------------------
local Config = {}

-- Базовые настройки
Config.Default = {
	theme           = "apple_glassmorphism",
	chatWindow = {
		font              = Enum.Font.Gotham,
		textSize          = 15,
		backgroundColor   = Color3.fromRGB(12, 12, 14),
		backgroundTransp  = 0.25,
		textColor         = Color3.fromRGB(245, 245, 247),
		backgroundImage   = "rbxassetid://95613504170054",
		imageTransparency = 0.85,
	},
	bubbleChat = {
		font              = Enum.Font.Gotham,
		textSize          = 14,
		backgroundColor   = Color3.fromRGB(20, 20, 22),
		backgroundTransp  = 0.15,
		textColor         = Color3.fromRGB(250, 250, 252),
		tailVisible       = false,
		cornerRadius      = 8,
		padding           = { top = 8, right = 12, bottom = 8, left = 12 },
	},
	chatInput = {
		font              = Enum.Font.Gotham,
		textSize          = 14,
		backgroundColor   = Color3.fromRGB(28, 28, 30),
		backgroundTransp  = 0.1,
		textColor         = Color3.fromRGB(230, 230, 232),
	},
	typingIndicator = {
		enabled           = true,
		backgroundColor   = Color3.fromRGB(30, 30, 32),
		backgroundTransp  = 0.3,
		textColor         = Color3.fromRGB(200, 200, 205),
		textSize          = 12,
		cornerRadius      = 12,
		animationSpeed    = 0.4,
		maxDots           = 3,
	},
	mentions = {
		enabled           = true,
		highlightColor    = Color3.fromRGB(100, 180, 255),
		pingSound         = true,
	},
	emojis = {
		enabled           = true,
		autoReplace       = true,
	},
	filters = {
		enabled           = true,
		words             = {},
		replacement       = "***",
	},
	notifications = {
		enabled           = true,
		soundEnabled      = true,
		volume            = 0.5,
	},
	history = {
		enabled           = true,
		maxEntries        = 500,
		saveToFile        = false,
	},
	stats = {
		enabled           = true,
		trackMessages     = true,
		trackEmojis       = true,
	},
	animations = {
		enabled           = true,
		fadeDuration      = 0.3,
		bounceEnabled     = true,
	},
	effects = {
		enabled           = true,
		particles         = true,
		glowEnabled       = false,
	},
	sounds = {
		messageSent       = "rbxassetid://6939556792",
		messageReceived   = "rbxassetid://6939556793",
		mention           = "rbxassetid://6939556794",
		commandSuccess    = "rbxassetid://6939556795",
		commandError      = "rbxassetid://6939556796",
	},
}

-- Текущая активная конфигурация
Config.Current = Utils.deepCopy(Config.Default)

-- Применение конфигурации
function Config.apply(overrides)
	Config.Current = Utils.mergeTables(Config.Default, overrides or {})
	return Config.Current
end

-- Сброс к дефолтным настройкам
function Config.reset()
	Config.Current = Utils.deepCopy(Config.Default)
	return Config.Current
end

-- Получение значения по пути (например, "chatWindow.textSize")
function Config.get(path)
	local parts = Utils.split(path, ".")
	local current = Config.Current
	for _, part in ipairs(parts) do
		if type(current) ~= "table" then return nil end
		current = current[part]
	end
	return current
end

-- Установка значения по пути
function Config.set(path, value)
	local parts = Utils.split(path, ".")
	local current = Config.Current
	for i = 1, #parts - 1 do
		local part = parts[i]
		if type(current[part]) ~= "table" then
			current[part] = {}
		end
		current = current[part]
	end
	current[parts[#parts]] = value
end

-- Сериализация конфигурации в JSON
function Config.serialize()
	local serializable = Utils.deepCopy(Config.Current)
	-- Преобразуем Color3 и Enum в строки для JSON
	local function sanitize(tbl)
		for key, value in pairs(tbl) do
			if typeof(value) == "Color3" then
				tbl[key] = { __type = "Color3", r = value.R, g = value.G, b = value.B }
			elseif typeof(value) == "EnumItem" then
				tbl[key] = { __type = "EnumItem", name = tostring(value) }
			elseif type(value) == "table" then
				sanitize(value)
			end
		end
	end
	sanitize(serializable)
	return HttpService:JSONEncode(serializable)
end

ChatSystem.Config = Config

--------------------------------------------------------------------------------
-- 🎨 СЕКЦИЯ 4: МОДУЛЬ ТЕМ (THEMES)
--------------------------------------------------------------------------------
local Themes = {}

Themes.List = {
	apple_glassmorphism = {
		name        = "Apple Glassmorphism",
		description = "Матовое стекло в стиле Apple",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(12, 12, 14),
			backgroundTransp  = 0.25,
			textColor         = Color3.fromRGB(245, 245, 247),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(20, 20, 22),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(250, 250, 252),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(28, 28, 30),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(230, 230, 232),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(30, 30, 32),
			textColor         = Color3.fromRGB(200, 200, 205),
		},
	},
	cyberpunk = {
		name        = "Cyberpunk",
		description = "Неоновые цвета киберпанка",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(10, 5, 25),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(0, 255, 200),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(20, 10, 40),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(255, 0, 200),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(30, 15, 60),
			backgroundTransp  = 0.05,
			textColor         = Color3.fromRGB(0, 255, 255),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(40, 20, 80),
			textColor         = Color3.fromRGB(255, 255, 0),
		},
	},
	sunset = {
		name        = "Sunset",
		description = "Тёплые закатные тона",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(45, 20, 35),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(255, 220, 180),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(60, 30, 45),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(255, 200, 150),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(70, 35, 50),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(255, 230, 200),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(80, 40, 55),
			textColor         = Color3.fromRGB(255, 210, 170),
		},
	},
	ocean = {
		name        = "Ocean",
		description = "Глубокие синие оттенки океана",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(5, 20, 45),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(180, 220, 255),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(10, 30, 60),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(150, 210, 255),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(15, 40, 75),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(200, 230, 255),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(20, 50, 90),
			textColor         = Color3.fromRGB(170, 215, 255),
		},
	},
	forest = {
		name        = "Forest",
		description = "Природные зелёные тона",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(10, 30, 20),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(200, 240, 200),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(15, 40, 25),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(180, 230, 180),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(20, 50, 30),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(210, 245, 210),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(25, 60, 35),
			textColor         = Color3.fromRGB(190, 235, 190),
		},
	},
	neon = {
		name        = "Neon",
		description = "Яркие неоновые акценты",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(0, 0, 0),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(255, 0, 255),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(10, 10, 10),
			backgroundTransp  = 0.05,
			textColor         = Color3.fromRGB(0, 255, 255),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(20, 20, 20),
			backgroundTransp  = 0.0,
			textColor         = Color3.fromRGB(255, 255, 0),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(30, 30, 30),
			textColor         = Color3.fromRGB(0, 255, 128),
		},
	},
	midnight = {
		name        = "Midnight",
		description = "Глубокая полночная тьма",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(5, 5, 15),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(200, 200, 220),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(10, 10, 25),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(210, 210, 230),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(15, 15, 35),
			backgroundTransp  = 0.05,
			textColor         = Color3.fromRGB(220, 220, 240),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(20, 20, 45),
			textColor         = Color3.fromRGB(190, 190, 210),
		},
	},
	rose_gold = {
		name        = "Rose Gold",
		description = "Элегантное розовое золото",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(40, 25, 30),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(255, 220, 225),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(50, 30, 35),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(255, 210, 215),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(60, 35, 40),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(255, 230, 235),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(70, 40, 45),
			textColor         = Color3.fromRGB(255, 215, 220),
		},
	},
	matrix = {
		name        = "Matrix",
		description = "Зелёный код в стиле Матрицы",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(0, 5, 0),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(0, 255, 0),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(0, 10, 0),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(50, 255, 50),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(0, 15, 0),
			backgroundTransp  = 0.05,
			textColor         = Color3.fromRGB(100, 255, 100),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(0, 20, 0),
			textColor         = Color3.fromRGB(150, 255, 150),
		},
	},
	aurora = {
		name        = "Aurora",
		description = "Северное сияние",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(15, 10, 40),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(180, 255, 220),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(20, 15, 50),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(200, 255, 230),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(25, 20, 60),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(220, 255, 240),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(30, 25, 70),
			textColor         = Color3.fromRGB(190, 255, 225),
		},
	},
	mono = {
		name        = "Monochrome",
		description = "Классический монохром",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(20, 20, 20),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(240, 240, 240),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(30, 30, 30),
			backgroundTransp  = 0.1,
			textColor         = Color3.fromRGB(250, 250, 250),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(40, 40, 40),
			backgroundTransp  = 0.05,
			textColor         = Color3.fromRGB(255, 255, 255),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(50, 50, 50),
			textColor         = Color3.fromRGB(230, 230, 230),
		},
	},
	candy = {
		name        = "Candy",
		description = "Сладкие пастельные тона",
		chatWindow = {
			backgroundColor   = Color3.fromRGB(255, 220, 235),
			backgroundTransp  = 0.25,
			textColor         = Color3.fromRGB(80, 40, 60),
		},
		bubbleChat = {
			backgroundColor   = Color3.fromRGB(255, 230, 240),
			backgroundTransp  = 0.2,
			textColor         = Color3.fromRGB(100, 50, 70),
		},
		chatInput = {
			backgroundColor   = Color3.fromRGB(255, 240, 245),
			backgroundTransp  = 0.15,
			textColor         = Color3.fromRGB(120, 60, 80),
		},
		typingIndicator = {
			backgroundColor   = Color3.fromRGB(255, 245, 250),
			textColor         = Color3.fromRGB(140, 70, 90),
		},
	},
}

-- Применение темы по имени
function Themes.apply(themeName)
	local theme = Themes.List[themeName]
	if not theme then
		Utils.warn("Тема не найдена: " .. tostring(themeName))
		return false
	end
	Config.Current.theme = themeName
	-- Применяем все секции темы
	for section, values in pairs(theme) do
		if section ~= "name" and section ~= "description" then
			if type(values) == "table" then
				for key, value in pairs(values) do
					Config.set(section .. "." .. key, value)
				end
			end
		end
	end
	Utils.info("Применена тема: " .. theme.name)
	return true
end

-- Получение списка всех тем
function Themes.getList()
	local result = {}
	for key, theme in pairs(Themes.List) do
		table.insert(result, {
			key         = key,
			name        = theme.name,
			description = theme.description,
		})
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

-- Получение информации о теме
function Themes.getInfo(themeName)
	return Themes.List[themeName]
end

ChatSystem.Themes = Themes

--------------------------------------------------------------------------------
-- 💬 СЕКЦИЯ 5: НАСТРОЙКА ОКНА ЧАТА (ЧАСТЬ 1 ОРИГИНАЛА)
--------------------------------------------------------------------------------
local ChatWindowModule = {}

function ChatWindowModule.setup()
	local cfg = Config.Current.chatWindow

	local chatWindow = TextChatService:FindFirstChild("ChatWindowConfiguration")
		or Instance.new("ChatWindowConfiguration", TextChatService)

	chatWindow.FontFace             = Font.fromEnum(cfg.font)
	chatWindow.TextSize             = cfg.textSize
	chatWindow.BackgroundColor3     = cfg.backgroundColor
	chatWindow.BackgroundTransparency = cfg.backgroundTransp
	chatWindow.TextColor3           = cfg.textColor

	-- Фоновое изображение
	local bgImage = chatWindow:FindFirstChild("ThemeBackground")
		or Instance.new("ImageLabel", chatWindow)
	bgImage.Name                = "ThemeBackground"
	bgImage.Image               = cfg.backgroundImage
	bgImage.BackgroundTransparency = 1
	bgImage.ImageTransparency   = cfg.imageTransparency
	bgImage.ScaleType           = Enum.ScaleType.Crop
	bgImage.LayoutOrder         = -1
	bgImage.ZIndex              = 0

	Utils.info("Окно чата настроено")
	return chatWindow
end

ChatSystem.ChatWindow = ChatWindowModule

--------------------------------------------------------------------------------
-- 🫧 СЕКЦИЯ 6: НАСТРОЙКА ПУЗЫРЬКОВОГО ЧАТА (ЧАСТЬ 2 ОРИГИНАЛА)
--------------------------------------------------------------------------------
local BubbleChatModule = {}

function BubbleChatModule.setup()
	local cfg = Config.Current.bubbleChat

	local bubbleChat = TextChatService:FindFirstChild("BubbleChatConfiguration")
		or Instance.new("BubbleChatConfiguration", TextChatService)

	bubbleChat.FontFace             = Font.fromEnum(cfg.font)
	bubbleChat.TextSize             = cfg.textSize
	bubbleChat.BackgroundColor3     = cfg.backgroundColor
	bubbleChat.BackgroundTransparency = cfg.backgroundTransp
	bubbleChat.TextColor3           = cfg.textColor
	bubbleChat.TailVisible          = cfg.tailVisible

	-- Скругление углов (UICorner)
	local corner = bubbleChat:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = bubbleChat
	end
	corner.CornerRadius = UDim.new(0, cfg.cornerRadius)

	-- Отступы (UIPadding)
	local padding = bubbleChat:FindFirstChildOfClass("UIPadding")
	if not padding then
		padding = Instance.new("UIPadding")
		padding.Parent = bubbleChat
	end
	padding.PaddingTop    = UDim.new(0, cfg.padding.top)
	padding.PaddingRight  = UDim.new(0, cfg.padding.right)
	padding.PaddingBottom = UDim.new(0, cfg.padding.bottom)
	padding.PaddingLeft   = UDim.new(0, cfg.padding.left)

	Utils.info("Пузырьковый чат настроен")
	return bubbleChat
end

ChatSystem.BubbleChat = BubbleChatModule

--------------------------------------------------------------------------------
-- ⌨️ СЕКЦИЯ 7: НАСТРОЙКА ПОЛЯ ВВОДА (ЧАСТЬ 3 ОРИГИНАЛА)
--------------------------------------------------------------------------------
local ChatInputModule = {}

function ChatInputModule.setup()
	local cfg = Config.Current.chatInput

	local chatInput = TextChatService:FindFirstChild("ChatInputBarConfiguration")
		or Instance.new("ChatInputBarConfiguration", TextChatService)

	chatInput.FontFace             = Font.fromEnum(cfg.font)
	chatInput.TextSize             = cfg.textSize
	chatInput.BackgroundColor3     = cfg.backgroundColor
	chatInput.BackgroundTransparency = cfg.backgroundTransp
	chatInput.TextColor3           = cfg.textColor

	Utils.info("Поле ввода настроено")
	return chatInput
end

ChatSystem.ChatInput = ChatInputModule

--------------------------------------------------------------------------------
-- ⌨️ СЕКЦИЯ 8: ИНДИКАТОР "ПЕЧАТАЕТ..." (ЧАСТЬ 4 ОРИГИНАЛА)
--------------------------------------------------------------------------------
local TypingIndicatorModule = {}
TypingIndicatorModule.gui = nil
TypingIndicatorModule.dots = 0
TypingIndicatorModule.running = false

function TypingIndicatorModule.setup()
	local cfg = Config.Current.typingIndicator
	if not cfg.enabled then return nil end

	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	-- Создаём BillboardGui
	local typingIndicator = Instance.new("BillboardGui")
	typingIndicator.Name          = "TypingIndicator"
	typingIndicator.Adornee       = head
	typingIndicator.Size          = UDim2.new(0, 100, 0, 35)
	typingIndicator.StudsOffset   = Vector3.new(0, 3, 0)
	typingIndicator.AlwaysOnTop   = true
	typingIndicator.Enabled       = false

	-- Фон индикатора
	local indicatorBg = Instance.new("Frame")
	indicatorBg.Name              = "Background"
	indicatorBg.Parent            = typingIndicator
	indicatorBg.Size              = UDim2.new(1, 0, 1, 0)
	indicatorBg.BackgroundColor3  = cfg.backgroundColor
	indicatorBg.BackgroundTransparency = cfg.backgroundTransp
	indicatorBg.BorderSizePixel   = 0

	-- Скругление
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, cfg.cornerRadius)
	uiCorner.Parent = indicatorBg

	-- Текст "печатает..."
	local typingText = Instance.new("TextLabel")
	typingText.Name              = "TypingText"
	typingText.Parent            = indicatorBg
	typingText.Size              = UDim2.new(1, 0, 1, 0)
	typingText.BackgroundTransparency = 1
	typingText.TextColor3        = cfg.textColor
	typingText.TextSize          = cfg.textSize
	typingText.Font              = Enum.Font.Gotham
	typingText.Text              = ""
	typingText.TextXAlignment    = Enum.TextXAlignment.Center
	typingText.TextYAlignment    = Enum.TextYAlignment.Center

	typingIndicator.Parent = playerGui

	TypingIndicatorModule.gui = typingIndicator

	-- Анимация точек
	TypingIndicatorModule.running = true
	task.spawn(function()
		while TypingIndicatorModule.running do
			if typingIndicator.Enabled then
				TypingIndicatorModule.dots = (TypingIndicatorModule.dots % cfg.maxDots) + 1
				typingText.Text = "печатает" .. string.rep(".", TypingIndicatorModule.dots)
				task.wait(cfg.animationSpeed)
			else
				typingText.Text = ""
				task.wait(0.1)
			end
		end
	end)

	-- Отслеживаем фокус на поле ввода
	local chatInputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if chatInputBar then
		chatInputBar:GetPropertyChangedSignal("IsFocused"):Connect(function()
			typingIndicator.Enabled = chatInputBar.IsFocused
		end)
	end

	Utils.info("Индикатор печати активирован")
	return typingIndicator
end

function TypingIndicatorModule.show()
	if TypingIndicatorModule.gui then
		TypingIndicatorModule.gui.Enabled = true
	end
end

function TypingIndicatorModule.hide()
	if TypingIndicatorModule.gui then
		TypingIndicatorModule.gui.Enabled = false
	end
end

function TypingIndicatorModule.destroy()
	TypingIndicatorModule.running = false
	if TypingIndicatorModule.gui then
		TypingIndicatorModule.gui:Destroy()
		TypingIndicatorModule.gui = nil
	end
end

ChatSystem.TypingIndicator = TypingIndicatorModule

--------------------------------------------------------------------------------
-- 😊 СЕКЦИЯ 9: СИСТЕМА ЭМОДЗИ (EMOJI SYSTEM)
--------------------------------------------------------------------------------
local EmojiSystem = {}

EmojiSystem.Map = {
	[":)"]      = "😊",
	[":("]      = "😢",
	[":D"]      = "😃",
	[";)"]      = "😉",
	[":P"]      = "😛",
	[":O"]      = "😮",
	["<3"]      = "❤️",
	["<33"]     = "💕",
	[":*"]      = "😘",
	[":@"]      = "😠",
	[":'("]     = "😭",
	["XD"]      = "😆",
	["B)"]      = "😎",
	[":/"]      = "😕",
	[":3"]      = "😺",
	["O_O"]     = "😳",
	["^_^"]     = "😄",
	["T_T"]     = "😿",
	[":fire:"]  = "🔥",
	[":star:"]  = "⭐",
	[":heart:"] = "💖",
	[":ok:"]    = "👌",
	[":thumb:"] = "👍",
	[":wave:"]  = "👋",
	[":clap:"]  = "👏",
	[":pray:"]  = "🙏",
	[":100:"]   = "💯",
	[":boom:"]  = "💥",
	[":sparkles:"] = "✨",
	[":rainbow:"]  = "🌈",
	[":sun:"]      = "☀️",
	[":moon:"]     = "🌙",
	[":coffee:"]   = "☕",
	[":pizza:"]    = "🍕",
	[":cake:"]     = "🍰",
	[":apple:"]    = "🍎",
	[":robot:"]    = "🤖",
	[":alien:"]    = "👽",
	[":ghost:"]    = "👻",
	[":skull:"]    = "💀",
}

-- Замена текстовых эмодзи на настоящие
function EmojiSystem.replace(text)
	if not Config.Current.emojis.enabled then return text end
	if not Config.Current.emojis.autoReplace then return text end

	local result = text
	for code, emoji in pairs(EmojiSystem.Map) do
		result = string.gsub(result, code, emoji)
	end
	return result
end

-- Получение списка всех эмодзи
function EmojiSystem.getList()
	local result = {}
	for code, emoji in pairs(EmojiSystem.Map) do
		table.insert(result, { code = code, emoji = emoji })
	end
	table.sort(result, function(a, b) return a.code < b.code end)
	return result
end

-- Добавление нового эмодзи
function EmojiSystem.add(code, emoji)
	EmojiSystem.Map[code] = emoji
	Utils.info("Добавлен эмодзи: " .. code .. " → " .. emoji)
end

-- Удаление эмодзи
function EmojiSystem.remove(code)
	if EmojiSystem.Map[code] then
		EmojiSystem.Map[code] = nil
		Utils.info("Удалён эмодзи: " .. code)
		return true
	end
	return false
end

ChatSystem.Emoji = EmojiSystem

--------------------------------------------------------------------------------
-- 📢 СЕКЦИЯ 10: СИСТЕМА УПОМИНАНИЙ (MENTION SYSTEM)
--------------------------------------------------------------------------------
local MentionSystem = {}

-- Поиск упоминаний @username в тексте
function MentionSystem.find(text)
	local mentions = {}
	for username in string.gmatch(text, "@([%w_]+)") do
		table.insert(mentions, username)
	end
	return mentions
end

-- Проверка, упомянут ли локальный игрок
function MentionSystem.isMentioned(text)
	local localName = string.lower(player.Name)
	local localDisplayName = string.lower(player.DisplayName)
	for _, mention in ipairs(MentionSystem.find(text)) do
		local lower = string.lower(mention)
		if lower == localName or lower == localDisplayName then
			return true
		end
	end
	return false
end

-- Подсветка упоминаний в тексте
function MentionSystem.highlight(text)
	if not Config.Current.mentions.enabled then return text end
	local color = Config.Current.mentions.highlightColor
	local hex = Utils.colorToHex(color)
	local result = text
	for username in string.gmatch(text, "@([%w_]+)") do
		local pattern = "@" .. username
		local replacement = string.format(
			'<font color="%s"><b>@%s</b></font>',
			hex, username
		)
		result = string.gsub(result, pattern, replacement)
	end
	return result
end

-- Обработка упоминания (звук, уведомление)
function MentionSystem.handle(text, sender)
	if not MentionSystem.isMentioned(text) then return false end
	if sender == player then return false end

	Utils.info("Вас упомянул: " .. tostring(sender))

	if Config.Current.notifications.enabled then
		ChatSystem.Notifications.mention(sender, text)
	end

	if Config.Current.notifications.soundEnabled and Config.Current.mentions.pingSound then
		ChatSystem.Sounds.play("mention")
	end

	return true
end

ChatSystem.Mentions = MentionSystem

--------------------------------------------------------------------------------
-- 🚫 СЕКЦИЯ 11: СИСТЕМА ФИЛЬТРОВ (FILTER SYSTEM)
--------------------------------------------------------------------------------
local FilterSystem = {}

-- Проверка текста на запрещённые слова
function FilterSystem.check(text)
	if not Config.Current.filters.enabled then
		return text, false
	end

	local lowerText = string.lower(text)
	local filtered = text
	local wasFiltered = false

	for _, word in ipairs(Config.Current.filters.words) do
		local lowerWord = string.lower(word)
		if string.find(lowerText, lowerWord, 1, true) then
			local pattern = word
			local replacement = string.rep(Config.Current.filters.replacement, #word)
			filtered = string.gsub(filtered, "(%a+)", function(match)
				if string.lower(match) == lowerWord then
					return replacement
				end
				return match
			end)
			wasFiltered = true
		end
	end

	return filtered, wasFiltered
end

-- Добавление слова в фильтр
function FilterSystem.addWord(word)
	word = Utils.trim(word)
	if word == "" then return false end
	for _, existing in ipairs(Config.Current.filters.words) do
		if string.lower(existing) == string.lower(word) then
			return false
		end
	end
	table.insert(Config.Current.filters.words, word)
	Utils.info("Добавлено слово в фильтр: " .. word)
	return true
end

-- Удаление слова из фильтра
function FilterSystem.removeWord(word)
	for i, existing in ipairs(Config.Current.filters.words) do
		if string.lower(existing) == string.lower(word) then
			table.remove(Config.Current.filters.words, i)
			Utils.info("Удалено слово из фильтра: " .. word)
			return true
		end
	end
	return false
end

-- Очистка фильтра
function FilterSystem.clear()
	Config.Current.filters.words = {}
	Utils.info("Фильтр очищен")
end

-- Получение списка фильтруемых слов
function FilterSystem.getWords()
	return Utils.deepCopy(Config.Current.filters.words)
end

ChatSystem.Filters = FilterSystem

--------------------------------------------------------------------------------
-- 🔔 СЕКЦИЯ 12: СИСТЕМА УВЕДОМЛЕНИЙ (NOTIFICATION SYSTEM)
--------------------------------------------------------------------------------
local NotificationSystem = {}
NotificationSystem.queue = {}
NotificationSystem.active = nil

function NotificationSystem.show(title, message, duration, type)
	if not Config.Current.notifications.enabled then return end
	duration = duration or 3
	type = type or "info"

	local colors = {
		info    = Color3.fromRGB(60, 130, 246),
		success = Color3.fromRGB(34, 197, 94),
		warning = Color3.fromRGB(234, 179, 8),
		error   = Color3.fromRGB(239, 68, 68),
		mention = Color3.fromRGB(168, 85, 247),
	}

	local color = colors[type] or colors.info

	-- Создаём ScreenGui для уведомления
	local notifGui = Instance.new("ScreenGui")
	notifGui.Name = "Notification_" .. Utils.generateId()
	notifGui.ResetOnSpawn = false
	notifGui.IgnoreGuiInset = true
	notifGui.DisplayOrder = 100
	notifGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "NotificationFrame"
	frame.Parent = notifGui
	frame.Size = UDim2.new(0, 320, 0, 80)
	frame.Position = UDim2.new(1, -340, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, 0)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = frame

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Parent = frame
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Parent = frame
	titleLabel.Size = UDim2.new(1, -20, 0, 24)
	titleLabel.Position = UDim2.new(0, 15, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Parent = frame
	messageLabel.Size = UDim2.new(1, -20, 0, 36)
	messageLabel.Position = UDim2.new(0, 15, 0, 36)
	messageLabel.BackgroundTransparency = 1
	messageLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	messageLabel.TextSize = 12
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.Text = Utils.truncate(message, 60)
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.TextWrapped = true

	-- Анимация появления
	frame.Position = UDim2.new(1, 20, 0, 20)
	frame.BackgroundTransparency = 1
	Utils.tween(frame, 0.3, {
		Position = UDim2.new(1, -340, 0, 20),
		BackgroundTransparency = 0.1,
	})

	-- Автоматическое исчезновение
	task.delay(duration, function()
		Utils.tween(frame, 0.3, {
			Position = UDim2.new(1, 20, 0, 20),
			BackgroundTransparency = 1,
		})
		task.wait(0.35)
		notifGui:Destroy()
	end)

	table.insert(NotificationSystem.queue, notifGui)
	return notifGui
end

function NotificationSystem.info(title, message)
	return NotificationSystem.show(title, message, 3, "info")
end

function NotificationSystem.success(title, message)
	return NotificationSystem.show(title, message, 3, "success")
end

function NotificationSystem.warning(title, message)
	return NotificationSystem.show(title, message, 4, "warning")
end

function NotificationSystem.error(title, message)
	return NotificationSystem.show(title, message, 5, "error")
end

function NotificationSystem.mention(sender, text)
	local title = "💬 Упоминание от " .. tostring(sender)
	return NotificationSystem.show(title, text, 5, "mention")
end

function NotificationSystem.clearAll()
	for _, gui in ipairs(NotificationSystem.queue) do
		pcall(function() gui:Destroy() end)
	end
	NotificationSystem.queue = {}
end

ChatSystem.Notifications = NotificationSystem

--------------------------------------------------------------------------------
-- 🔊 СЕКЦИЯ 13: СИСТЕМА ЗВУКОВ (SOUND SYSTEM)
--------------------------------------------------------------------------------
local SoundSystem = {}
SoundSystem.cache = {}

function SoundSystem.play(soundType)
	if not Config.Current.notifications.soundEnabled then return end
	local soundId = Config.Current.sounds[soundType]
	if not soundId then return end

	-- Проверяем кэш
	if SoundSystem.cache[soundType] then
		local cached = SoundSystem.cache[soundType]
		cached:Stop()
		cached:Play()
		return cached
	end

	local sound = Instance.new("Sound")
	sound.Name = "ChatSound_" .. soundType
	sound.SoundId = soundId
	sound.Volume = Config.Current.notifications.volume
	sound.Parent = SoundService
	sound:Play()

	-- Удаляем после воспроизведения
	sound.Ended:Connect(function()
		sound:Destroy()
		SoundSystem.cache[soundType] = nil
	end)

	SoundSystem.cache[soundType] = sound
	return sound
end

function SoundSystem.setVolume(volume)
	Config.Current.notifications.volume = Utils.clamp(volume, 0, 1)
end

function SoundSystem.testAll()
	for soundType, _ in pairs(Config.Current.sounds) do
		SoundSystem.play(soundType)
		task.wait(0.5)
	end
end

ChatSystem.Sounds = SoundSystem

--------------------------------------------------------------------------------
-- 📜 СЕКЦИЯ 14: СИСТЕМА ИСТОРИИ (HISTORY SYSTEM)
--------------------------------------------------------------------------------
local HistorySystem = {}
HistorySystem.entries = {}
HistorySystem.maxEntries = 500

function HistorySystem.add(entry)
	if not Config.Current.history.enabled then return end

	local record = {
		id        = Utils.generateId("msg"),
		timestamp = os.time(),
		sender    = entry.sender or "System",
		text      = entry.text or "",
		type      = entry.type or "message",
		channel   = entry.channel or "default",
	}

	table.insert(HistorySystem.entries, record)

	-- Ограничение размера
	while #HistorySystem.entries > Config.Current.history.maxEntries do
		table.remove(HistorySystem.entries, 1)
	end

	return record
end

function HistorySystem.getAll()
	return Utils.deepCopy(HistorySystem.entries)
end

function HistorySystem.search(query)
	query = string.lower(query)
	local results = {}
	for _, entry in ipairs(HistorySystem.entries) do
		if string.find(string.lower(entry.text), query, 1, true)
			or string.find(string.lower(entry.sender), query, 1, true) then
			table.insert(results, entry)
		end
	end
	return results
end

function HistorySystem.getBySender(sender)
	local results = {}
	for _, entry in ipairs(HistorySystem.entries) do
		if string.lower(entry.sender) == string.lower(sender) then
			table.insert(results, entry)
		end
	end
	return results
end

function HistorySystem.getRecent(count)
	count = count or 10
	local result = {}
	local startIdx = math.max(1, #HistorySystem.entries - count + 1)
	for i = startIdx, #HistorySystem.entries do
		table.insert(result, HistorySystem.entries[i])
	end
	return result
end

function HistorySystem.clear()
	HistorySystem.entries = {}
	Utils.info("История очищена")
end

function HistorySystem.export()
	return HttpService:JSONEncode(HistorySystem.entries)
end

function HistorySystem.getCount()
	return #HistorySystem.entries
end

ChatSystem.History = HistorySystem

--------------------------------------------------------------------------------
-- 📊 СЕКЦИЯ 15: СИСТЕМА СТАТИСТИКИ (STATS SYSTEM)
--------------------------------------------------------------------------------
local StatsSystem = {}

StatsSystem.Data = {
	messagesSent     = 0,
	messagesReceived = 0,
	commandsUsed     = 0,
	emojisUsed       = 0,
	mentionsReceived = 0,
	mentionsSent     = 0,
	themesChanged    = 0,
	notificationsShown = 0,
	sessionStart     = os.time(),
	mostUsedEmojis   = {},
	mostActiveUsers  = {},
}

function StatsSystem.increment(key, amount)
	if not Config.Current.stats.enabled then return end
	amount = amount or 1
	if StatsSystem.Data[key] == nil then
		StatsSystem.Data[key] = 0
	end
	StatsSystem.Data[key] = StatsSystem.Data[key] + amount
end

function StatsSystem.get(key)
	if key then
		return StatsSystem.Data[key]
	end
	return Utils.deepCopy(StatsSystem.Data)
end

function StatsSystem.getSessionDuration()
	return os.time() - StatsSystem.Data.sessionStart
end

function StatsSystem.formatDuration(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

function StatsSystem.trackEmoji(emoji)
	if not Config.Current.stats.trackEmojis then return end
	StatsSystem.Data.mostUsedEmojis[emoji] = (StatsSystem.Data.mostUsedEmojis[emoji] or 0) + 1
end

function StatsSystem.trackUser(username)
	if not Config.Current.stats.trackMessages then return end
	StatsSystem.Data.mostActiveUsers[username] = (StatsSystem.Data.mostActiveUsers[username] or 0) + 1
end

function StatsSystem.getTopEmojis(count)
	count = count or 5
	local list = {}
	for emoji, uses in pairs(StatsSystem.Data.mostUsedEmojis) do
		table.insert(list, { emoji = emoji, uses = uses })
	end
	table.sort(list, function(a, b) return a.uses > b.uses end)
	local result = {}
	for i = 1, math.min(count, #list) do
		table.insert(result, list[i])
	end
	return result
end

function StatsSystem.getTopUsers(count)
	count = count or 5
	local list = {}
	for user, msgs in pairs(StatsSystem.Data.mostActiveUsers) do
		table.insert(list, { user = user, messages = msgs })
	end
	table.sort(list, function(a, b) return a.messages > b.messages end)
	local result = {}
	for i = 1, math.min(count, #list) do
		table.insert(result, list[i])
	end
	return result
end

function StatsSystem.reset()
	local sessionStart = StatsSystem.Data.sessionStart
	StatsSystem.Data = {
		messagesSent     = 0,
		messagesReceived = 0,
		commandsUsed     = 0,
		emojisUsed       = 0,
		mentionsReceived = 0,
		mentionsSent     = 0,
		themesChanged    = 0,
		notificationsShown = 0,
		sessionStart     = sessionStart,
		mostUsedEmojis   = {},
		mostActiveUsers  = {},
	}
	Utils.info("Статистика сброшена")
end

function StatsSystem.getSummary()
	local data = StatsSystem.Data
	return string.format(
		"📊 Статистика сессии:\n" ..
		"  ⏱ Длительность: %s\n" ..
		"  📤 Отправлено: %d\n" ..
		"  📥 Получено: %d\n" ..
		"  ⚡ Команд: %d\n" ..
		"  😊 Эмодзи: %d\n" ..
		"  📢 Упоминаний получено: %d\n" ..
		"  🔔 Уведомлений: %d",
		StatsSystem.formatDuration(StatsSystem.getSessionDuration()),
		data.messagesSent,
		data.messagesReceived,
		data.commandsUsed,
		data.emojisUsed,
		data.mentionsReceived,
		data.notificationsShown
	)
end

ChatSystem.Stats = StatsSystem

--------------------------------------------------------------------------------
-- ✨ СЕКЦИЯ 16: СИСТЕМА АНИМАЦИЙ (ANIMATION SYSTEM)
--------------------------------------------------------------------------------
local AnimationSystem = {}

-- Плавное появление элемента
function AnimationSystem.fadeIn(instance, duration)
	if not Config.Current.animations.enabled then return end
	duration = duration or Config.Current.animations.fadeDuration
	instance.BackgroundTransparency = 1
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.TextTransparency = 1
	end
	Utils.tween(instance, duration, {
		BackgroundTransparency = 0,
		TextTransparency = 0,
	})
end

-- Плавное исчезновение элемента
function AnimationSystem.fadeOut(instance, duration)
	if not Config.Current.animations.enabled then return end
	duration = duration or Config.Current.animations.fadeDuration
	Utils.tween(instance, duration, {
		BackgroundTransparency = 1,
		TextTransparency = 1,
	})
end

-- Эффект подпрыгивания
function AnimationSystem.bounce(instance)
	if not Config.Current.animations.enabled then return end
	if not Config.Current.animations.bounceEnabled then return end

	local original = instance.Position
	Utils.tween(instance, 0.1, {
		Position = original + UDim2.new(0, 0, 0, -5),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	task.delay(0.1, function()
		Utils.tween(instance, 0.15, {
			Position = original,
		}, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	end)
end

-- Пульсация
function AnimationSystem.pulse(instance, times, duration)
	if not Config.Current.animations.enabled then return end
	times = times or 3
	duration = duration or 0.3

	task.spawn(function()
		for i = 1, times do
			Utils.tween(instance, duration / 2, {
				Size = instance.Size * UDim2.new(1.05, 0, 1.05, 0),
			})
			task.wait(duration / 2)
			Utils.tween(instance, duration / 2, {
				Size = instance.Size / UDim2.new(1.05, 0, 1.05, 0),
			})
			task.wait(duration / 2)
		end
	end)
end

-- Эффект печатной машинки
function AnimationSystem.typewriter(textLabel, text, speed)
	if not Config.Current.animations.enabled then
		textLabel.Text = text
		return
	end
	speed = speed or 0.03
	textLabel.Text = ""
	task.spawn(function()
		for i = 1, #text do
			textLabel.Text = string.sub(text, 1, i)
			task.wait(speed)
		end
	end)
end

-- Плавное изменение цвета
function AnimationSystem.colorTransition(instance, targetColor, duration)
	if not Config.Current.animations.enabled then
		instance.BackgroundColor3 = targetColor
		return
	end
	duration = duration or 0.5
	Utils.tween(instance, duration, {
		BackgroundColor3 = targetColor,
	})
end

-- Тряска элемента
function AnimationSystem.shake(instance, intensity, duration)
	if not Config.Current.animations.enabled then return end
	intensity = intensity or 5
	duration = duration or 0.3
	local original = instance.Position
	local startTime = os.clock()

	task.spawn(function()
		while os.clock() - startTime < duration do
			local offsetX = math.random(-intensity, intensity)
			local offsetY = math.random(-intensity, intensity)
			instance.Position = original + UDim2.new(0, offsetX, 0, offsetY)
			task.wait(0.02)
		end
		instance.Position = original
	end)
end

ChatSystem.Animations = AnimationSystem

--------------------------------------------------------------------------------
-- 🌟 СЕКЦИЯ 17: СИСТЕМА ЭФФЕКТОВ (EFFECTS SYSTEM)
--------------------------------------------------------------------------------
local EffectsSystem = {}

-- Создание частиц при событии
function EffectsSystem.spawnParticles(position, color, count)
	if not Config.Current.effects.enabled then return end
	if not Config.Current.effects.particles then return end

	count = count or 10
	local attachment = Instance.new("Part")
	attachment.Name = "ParticleEmitter_" .. Utils.generateId()
	attachment.Size = Vector3.new(0.1, 0.1, 0.1)
	attachment.Position = position or Vector3.new(0, 0, 0)
	attachment.Anchored = true
	attachment.CanCollide = false
	attachment.Transparency = 1
	attachment.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.2, 0)
	emitter.Parent = attachment

	emitter:Emit(count)

	task.delay(2, function()
		attachment:Destroy()
	end)
end

-- Эффект свечения
function EffectsSystem.enableGlow(instance, color)
	if not Config.Current.effects.enabled then return end
	if not Config.Current.effects.glowEnabled then return end

	local existing = instance:FindFirstChild("GlowEffect")
	if existing then existing:Destroy() end

	local glow = Instance.new("ImageLabel")
	glow.Name = "GlowEffect"
	glow.Parent = instance
	glow.Size = UDim2.new(1.2, 0, 1.2, 0)
	glow.Position = UDim2.new(-0.1, 0, -0.1, 0)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://3570695787"
	glow.ImageColor3 = color or Color3.new(1, 1, 1)
	glow.ImageTransparency = 0.5
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(100, 100, 100, 100)
	glow.ZIndex = instance.ZIndex - 1

	return glow
end

-- Отключение свечения
function EffectsSystem.disableGlow(instance)
	local glow = instance:FindFirstChild("GlowEffect")
	if glow then glow:Destroy() end
end

-- Эффект мерцания
function EffectsSystem.flicker(instance, times, duration)
	if not Config.Current.effects.enabled then return end
	times = times or 5
	duration = duration or 0.1

	task.spawn(function()
		for i = 1, times do
			instance.BackgroundTransparency = 0.8
			task.wait(duration)
			instance.BackgroundTransparency = 0.1
			task.wait(duration)
		end
	end)
end

-- Волновой эффект
function EffectsSystem.wave(instance, amplitude, frequency, duration)
	if not Config.Current.effects.enabled then return end
	amplitude = amplitude or 3
	frequency = frequency or 2
	duration = duration or 1

	local original = instance.Position
	local startTime = os.clock()

	task.spawn(function()
		while os.clock() - startTime < duration do
			local elapsed = os.clock() - startTime
			local offset = math.sin(elapsed * frequency * math.pi * 2) * amplitude
			instance.Position = original + UDim2.new(0, 0, 0, offset)
			task.wait(0.02)
		end
		instance.Position = original
	end)
end

ChatSystem.Effects = EffectsSystem

--------------------------------------------------------------------------------
-- 💾 СЕКЦИЯ 18: СИСТЕМА СОХРАНЕНИЯ/ЗАГРУЗКИ (SAVE/LOAD SYSTEM)
--------------------------------------------------------------------------------
local SaveLoadSystem = {}

-- Сохранение конфигурации в строку
function SaveLoadSystem.exportConfig()
	return Config.serialize()
end

-- Загрузка конфигурации из строки
function SaveLoadSystem.importConfig(jsonString)
	local success, data = pcall(function()
		return HttpService:JSONDecode(jsonString)
	end)

	if not success then
		Utils.error("Не удалось декодировать конфигурацию")
		return false
	end

	-- Обратное преобразование Color3 и Enum
	local function deserialize(tbl)
		for key, value in pairs(tbl) do
			if type(value) == "table" and value.__type == "Color3" then
				tbl[key] = Color3.new(value.r, value.g, value.b)
			elseif type(value) == "table" and value.__type == "EnumItem" then
				local parts = Utils.split(value.name, ".")
				local enumType = Enum[parts[2]]
				if enumType then
					tbl[key] = enumType[parts[3]]
				end
			elseif type(value) == "table" then
				deserialize(value)
			end
		end
	end
	deserialize(data)

	Config.apply(data)
	Utils.info("Конфигурация импортирована")
	return true
end

-- Сохранение в PlayerData (если доступно)
function SaveLoadSystem.saveToDataStore()
	Utils.warn("DataStore сохранение требует серверной части")
	return false
end

-- Получение краткой сводки конфигурации
function SaveLoadSystem.getSummary()
	local cfg = Config.Current
	return string.format(
		"🎨 Тема: %s\n" ..
		"📏 Размер шрифта чата: %d\n" ..
		"📏 Размер шрифта пузырей: %d\n" ..
		"😊 Эмодзи: %s\n" ..
		"📢 Упоминания: %s\n" ..
		"🚫 Фильтры: %s (%d слов)\n" ..
		"🔔 Уведомления: %s\n" ..
		"🔊 Звуки: %s\n" ..
		"✨ Анимации: %s\n" ..
		"🌟 Эффекты: %s",
		tostring(cfg.theme),
		cfg.chatWindow.textSize,
		cfg.bubbleChat.textSize,
		cfg.emojis.enabled and "ВКЛ" or "ВЫКЛ",
		cfg.mentions.enabled and "ВКЛ" or "ВЫКЛ",
		cfg.filters.enabled and "ВКЛ" or "ВЫКЛ",
		#cfg.filters.words,
		cfg.notifications.enabled and "ВКЛ" or "ВЫКЛ",
		cfg.notifications.soundEnabled and "ВКЛ" or "ВЫКЛ",
		cfg.animations.enabled and "ВКЛ" or "ВЫКЛ",
		cfg.effects.enabled and "ВКЛ" or "ВЫКЛ"
	)
end

ChatSystem.SaveLoad = SaveLoadSystem

--------------------------------------------------------------------------------
-- ⚡ СЕКЦИЯ 19: СИСТЕМА КОМАНД (COMMAND SYSTEM)
--------------------------------------------------------------------------------
local CommandSystem = {}
CommandSystem.Commands = {}
CommandSystem.Prefix = "/"

-- Регистрация команды
function CommandSystem.register(name, description, callback, aliases)
	CommandSystem.Commands[name] = {
		name        = name,
		description = description,
		callback    = callback,
		aliases     = aliases or {},
	}
	for _, alias in ipairs(aliases or {}) do
		CommandSystem.Commands[alias] = CommandSystem.Commands[name]
	end
end

-- Выполнение команды
function CommandSystem.execute(input)
	if not string.startswith(input, CommandSystem.Prefix) then
		return false
	end

	local parts = Utils.split(input:sub(2), " ")
	local cmdName = string.lower(parts[1])
	local args = {}
	for i = 2, #parts do
		table.insert(args, parts[i])
	end

	local command = CommandSystem.Commands[cmdName]
	if not command then
		ChatSystem.Notifications.error("❌ Команда не найдена", "Используйте /help для списка команд")
		ChatSystem.Sounds.play("commandError")
		return false
	end

	StatsSystem.increment("commandsUsed")
	local success, result = pcall(command.callback, args)
	if not success then
		ChatSystem.Notifications.error("❌ Ошибка выполнения", tostring(result))
		return false
	end

	ChatSystem.Sounds.play("commandSuccess")
	return true
end

-- Получение списка команд
function CommandSystem.getList()
	local list = {}
	local seen = {}
	for name, cmd in pairs(CommandSystem.Commands) do
		if not seen[cmd.name] then
			table.insert(list, {
				name        = cmd.name,
				description = cmd.description,
				aliases     = cmd.aliases,
			})
			seen[cmd.name] = true
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

--------------------------------------------------------------------------------
-- 📝 РЕГИСТРАЦИЯ ВСЕХ КОМАНД
--------------------------------------------------------------------------------

CommandSystem.register("help", "Показать список всех команд", function(args)
	local list = CommandSystem.getList()
	local text = "📋 Доступные команды:\n"
	for _, cmd in ipairs(list) do
		local aliases = #cmd.aliases > 0 and " (" .. table.concat(cmd.aliases, ", ") .. ")" or ""
		text = text .. "  • /" .. cmd.name .. aliases .. " — " .. cmd.description .. "\n"
	end
	ChatSystem.Notifications.info("📋 Список команд", "Выведен в консоль")
	print(text)
end, { "h", "commands" })

CommandSystem.register("theme", "Применить тему (/theme <имя>)", function(args)
	if #args < 1 then
		local themes = Themes.getList()
		local text = "🎨 Доступные темы:\n"
		for _, theme in ipairs(themes) do
			text = text .. "  • " .. theme.key .. " — " .. theme.name .. "\n"
		end
		print(text)
		ChatSystem.Notifications.info("🎨 Темы", "Список выведен в консоль")
		return
	end

	local themeName = string.lower(args[1])
	if Themes.apply(themeName) then
		ChatWindowModule.setup()
		BubbleChatModule.setup()
		ChatInputModule.setup()
		StatsSystem.increment("themesChanged")
		ChatSystem.Notifications.success("✅ Тема применена", Themes.getInfo(themeName).name)
	else
		ChatSystem.Notifications.error("❌ Тема не найдена", themeName)
	end
end, { "t" })

CommandSystem.register("clear", "Очистить историю чата", function(args)
	HistorySystem.clear()
	ChatSystem.Notifications.success("🗑️ История очищена", "Все записи удалены")
end, { "c" })

CommandSystem.register("size", "Изменить размер шрифта (/size <число>)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.info("📏 Текущий размер", tostring(Config.Current.chatWindow.textSize))
		return
	end
	local newSize = tonumber(args[1])
	if not newSize or newSize < 8 or newSize > 40 then
		ChatSystem.Notifications.error("❌ Неверный размер", "Допустимо: 8-40")
		return
	end
	Config.Current.chatWindow.textSize = newSize
	Config.Current.bubbleChat.textSize = math.max(8, newSize - 1)
	Config.Current.chatInput.textSize = math.max(8, newSize - 1)
	ChatWindowModule.setup()
	BubbleChatModule.setup()
	ChatInputModule.setup()
	ChatSystem.Notifications.success("📏 Размер изменён", tostring(newSize))
end, { "s" })

CommandSystem.register("color", "Изменить цвет текста (/color <hex>)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.info("🎨 Текущий цвет", Utils.colorToHex(Config.Current.chatWindow.textColor))
		return
	end
	local hex = args[1]
	if not string.match(hex, "^#?[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
		ChatSystem.Notifications.error("❌ Неверный HEX", "Пример: #FF5500")
		return
	end
	local color = Utils.hexToColor(hex)
	Config.Current.chatWindow.textColor = color
	Config.Current.bubbleChat.textColor = color
	ChatWindowModule.setup()
	BubbleChatModule.setup()
	ChatSystem.Notifications.success("🎨 Цвет изменён", hex)
end)

CommandSystem.register("blur", "Изменить прозрачность (/blur <0-1>)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.info("🌫️ Прозрачность", tostring(Config.Current.chatWindow.backgroundTransp))
		return
	end
	local value = tonumber(args[1])
	if not value or value < 0 or value > 1 then
		ChatSystem.Notifications.error("❌ Неверное значение", "Допустимо: 0-1")
		return
	end
	Config.Current.chatWindow.backgroundTransp = value
	Config.Current.bubbleChat.backgroundTransp = math.max(0, value - 0.1)
	ChatWindowModule.setup()
	BubbleChatModule.setup()
	ChatSystem.Notifications.success("🌫️ Прозрачность", tostring(value))
end)

CommandSystem.register("font", "Изменить шрифт (/font <имя>)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.info("🔤 Текущий шрифт", tostring(Config.Current.chatWindow.font))
		return
	end
	local fontName = args[1]
	local fontEnum = Enum.Font[fontName]
	if not fontEnum then
		ChatSystem.Notifications.error("❌ Шрифт не найден", fontName)
		return
	end
	Config.Current.chatWindow.font = fontEnum
	Config.Current.bubbleChat.font = fontEnum
	Config.Current.chatInput.font = fontEnum
	ChatWindowModule.setup()
	BubbleChatModule.setup()
	ChatInputModule.setup()
	ChatSystem.Notifications.success("🔤 Шрифт изменён", fontName)
end, { "f" })

CommandSystem.register("bubble", "Вкл/выкл хвостик пузырей", function(args)
	Config.Current.bubbleChat.tailVisible = not Config.Current.bubbleChat.tailVisible
	BubbleChatModule.setup()
	local state = Config.Current.bubbleChat.tailVisible and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("🫧 Хвостик", state)
end)

CommandSystem.register("typing", "Вкл/выкл индикатор печати", function(args)
	Config.Current.typingIndicator.enabled = not Config.Current.typingIndicator.enabled
	if Config.Current.typingIndicator.enabled then
		TypingIndicatorModule.setup()
	else
		TypingIndicatorModule.destroy()
	end
	local state = Config.Current.typingIndicator.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("⌨️ Индикатор печати", state)
end)

CommandSystem.register("emoji", "Вкл/выкл систему эмодзи", function(args)
	Config.Current.emojis.enabled = not Config.Current.emojis.enabled
	local state = Config.Current.emojis.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("😊 Эмодзи", state)
end)

CommandSystem.register("mention", "Вкл/выкл систему упоминаний", function(args)
	Config.Current.mentions.enabled = not Config.Current.mentions.enabled
	local state = Config.Current.mentions.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("📢 Упоминания", state)
end)

CommandSystem.register("filter", "Управление фильтром (/filter add|remove|clear|list)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.info("🚫 Фильтр", "Используйте: add, remove, clear, list")
		return
	end
	local sub = string.lower(args[1])
	if sub == "list" then
		local words = FilterSystem.getWords()
		if #words == 0 then
			ChatSystem.Notifications.info("🚫 Фильтр пуст", "Нет запрещённых слов")
		else
			print("🚫 Запрещённые слова: " .. table.concat(words, ", "))
			ChatSystem.Notifications.info("🚫 Фильтр", tostring(#words) .. " слов в консоли")
		end
	elseif sub == "add" and args[2] then
		if FilterSystem.addWord(args[2]) then
			ChatSystem.Notifications.success("✅ Добавлено", args[2])
		end
	elseif sub == "remove" and args[2] then
		if FilterSystem.removeWord(args[2]) then
			ChatSystem.Notifications.success("✅ Удалено", args[2])
		end
	elseif sub == "clear" then
		FilterSystem.clear()
		ChatSystem.Notifications.success("🗑️ Фильтр очищен", "")
	end
end)

CommandSystem.register("stats", "Показать статистику", function(args)
	local summary = StatsSystem.getSummary()
	print(summary)
	ChatSystem.Notifications.info("📊 Статистика", "Выведена в консоль")
end)

CommandSystem.register("reset", "Сбросить все настройки", function(args)
	Config.reset()
	ChatWindowModule.setup()
	BubbleChatModule.setup()
	ChatInputModule.setup()
	TypingIndicatorModule.destroy()
	if Config.Current.typingIndicator.enabled then
		TypingIndicatorModule.setup()
	end
	ChatSystem.Notifications.success("🔄 Настройки сброшены", "Все параметры по умолчанию")
end)

CommandSystem.register("export", "Экспорт конфигурации в JSON", function(args)
	local json = SaveLoadSystem.exportConfig()
	print("📤 Экспорт конфигурации:\n" .. json)
	ChatSystem.Notifications.success("📤 Экспорт", "JSON выведен в консоль")
end)

CommandSystem.register("import", "Импорт конфигурации из JSON", function(args)
	if #args < 1 then
		ChatSystem.Notifications.warning("📥 Импорт", "Используйте: /import <json>")
		return
	end
	local json = table.concat(args, " ")
	if SaveLoadSystem.importConfig(json) then
		ChatWindowModule.setup()
		BubbleChatModule.setup()
		ChatInputModule.setup()
		ChatSystem.Notifications.success("📥 Импорт успешен", "Конфигурация загружена")
	else
		ChatSystem.Notifications.error("❌ Ошибка импорта", "Неверный JSON")
	end
end)

CommandSystem.register("sound", "Вкл/выкл звуки", function(args)
	Config.Current.notifications.soundEnabled = not Config.Current.notifications.soundEnabled
	local state = Config.Current.notifications.soundEnabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("🔊 Звуки", state)
end)

CommandSystem.register("notify", "Вкл/выкл уведомления", function(args)
	Config.Current.notifications.enabled = not Config.Current.notifications.enabled
	local state = Config.Current.notifications.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("🔔 Уведомления", state)
end)

CommandSystem.register("anim", "Вкл/выкл анимации", function(args)
	Config.Current.animations.enabled = not Config.Current.animations.enabled
	local state = Config.Current.animations.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("✨ Анимации", state)
end)

CommandSystem.register("effect", "Вкл/выкл эффекты", function(args)
	Config.Current.effects.enabled = not Config.Current.effects.enabled
	local state = Config.Current.effects.enabled and "ВКЛ" or "ВЫКЛ"
	ChatSystem.Notifications.success("🌟 Эффекты", state)
end)

CommandSystem.register("history", "Показать последние сообщения", function(args)
	local count = tonumber(args[1]) or 10
	local recent = HistorySystem.getRecent(count)
	if #recent == 0 then
		ChatSystem.Notifications.info("📜 История пуста", "Нет записей")
		return
	end
	print("📜 Последние " .. #recent .. " сообщений:")
	for _, entry in ipairs(recent) do
		print(string.format("  [%s] %s: %s",
			Utils.formatTime(entry.timestamp),
			entry.sender,
			Utils.truncate(entry.text, 50)))
	end
	ChatSystem.Notifications.info("📜 История", tostring(#recent) .. " записей в консоли")
end)

CommandSystem.register("search", "Поиск в истории (/search <запрос>)", function(args)
	if #args < 1 then
		ChatSystem.Notifications.warning("🔍 Поиск", "Укажите запрос")
		return
	end
	local query = table.concat(args, " ")
	local results = HistorySystem.search(query)
	if #results == 0 then
		ChatSystem.Notifications.info("🔍 Ничего не найдено", query)
		return
	end
	print("🔍 Найдено " .. #results .. " совпадений:")
	for _, entry in ipairs(results) do
		print(string.format("  [%s] %s: %s",
			Utils.formatTime(entry.timestamp),
			entry.sender,
			Utils.truncate(entry.text, 50)))
	end
	ChatSystem.Notifications.success("🔍 Поиск", tostring(#results) .. " совпадений")
end)

CommandSystem.register("emojis", "Список всех эмодзи", function(args)
	local list = EmojiSystem.getList()
	print("😊 Доступные эмодзи (" .. #list .. "):")
	for _, item in ipairs(list) do
		print(string.format("  %s → %s", item.code, item.emoji))
	end
	ChatSystem.Notifications.info("😊 Эмодзи", tostring(#list) .. " в консоли")
end)

CommandSystem.register("test", "Тестовое уведомление", function(args)
	ChatSystem.Notifications.info("🧪 Тест", "Это тестовое уведомление")
	task.wait(0.5)
	ChatSystem.Notifications.success("✅ Успех", "Всё работает!")
	task.wait(0.5)
	ChatSystem.Notifications.warning("⚠️ Внимание", "Тестовое предупреждение")
	task.wait(0.5)
	ChatSystem.Notifications.error("❌ Ошибка", "Тестовая ошибка")
end)

CommandSystem.register("version", "Показать версию системы", function(args)
	ChatSystem.Notifications.info("🍎 Chat System", "v" .. ChatSystem.Version)
end, { "v" })

CommandSystem.register("summary", "Краткая сводка настроек", function(args)
	local summary = SaveLoadSystem.getSummary()
	print(summary)
	ChatSystem.Notifications.info("📋 Сводка", "Выведена в консоль")
end)

CommandSystem.register("top", "Топ эмодзи и пользователей", function(args)
	local topEmojis = StatsSystem.getTopEmojis(5)
	local topUsers = StatsSystem.getTopUsers(5)
	print("🏆 Топ эмодзи:")
	for _, item in ipairs(topEmojis) do
		print("  " .. item.emoji .. " — " .. item.uses .. " раз")
	end
	print("👥 Топ пользователей:")
	for _, item in ipairs(topUsers) do
		print("  " .. item.user .. " — " .. item.messages .. " сообщ.")
	end
	ChatSystem.Notifications.info("🏆 Топ", "В консоли")
end)

ChatSystem.Commands = CommandSystem

--------------------------------------------------------------------------------
-- 🔗 СЕКЦИЯ 20: СИСТЕМА ХУКОВ (HOOKS SYSTEM)
--------------------------------------------------------------------------------
local HooksSystem = {}

function HooksSystem.register(event, callback)
	if not ChatSystem.Hooks[event] then
		ChatSystem.Hooks[event] = {}
	end
	table.insert(ChatSystem.Hooks[event], callback)
end

function HooksSystem.fire(event, ...)
	local hooks = ChatSystem.Hooks[event]
	if not hooks then return end
	for _, callback in ipairs(hooks) do
		Utils.safeCall(callback, ...)
	end
end

function HooksSystem.clear(event)
	ChatSystem.Hooks[event] = {}
end

ChatSystem.HooksSystem = HooksSystem

--------------------------------------------------------------------------------
-- 🎯 СЕКЦИЯ 21: ОБРАБОТКА СООБЩЕНИЙ (MESSAGE HANDLER)
--------------------------------------------------------------------------------
local MessageHandler = {}

function MessageHandler.onIncoming(message)
	Utils.safeCall(function()
		local text = message.Text or ""
		local sender = message.TextSource and message.TextSource.Name or "System"

		-- Трекинг статистики
		StatsSystem.increment("messagesReceived")
		StatsSystem.trackUser(sender)

		-- Обработка упоминаний
		if MentionSystem.isMentioned(text) then
			StatsSystem.increment("mentionsReceived")
			MentionSystem.handle(text, Players:FindFirstChild(sender))
		end

		-- Добавление в историю
		HistorySystem.add({
			sender = sender,
			text   = text,
			type   = "incoming",
		})

		-- Звук при получении
		if Config.Current.notifications.soundEnabled then
			SoundSystem.play("messageReceived")
		end

		HooksSystem.fire("messageReceived", message)
	end)
end

function MessageHandler.onOutgoing(text)
	Utils.safeCall(function()
		-- Замена эмодзи
		local processed = EmojiSystem.replace(text)

		-- Применение фильтра
		local filtered, wasFiltered = FilterSystem.check(processed)
		if wasFiltered then
			Utils.info("Сообщение отфильтровано")
		end

		-- Подсветка упоминаний
		if Config.Current.mentions.enabled then
			processed = MentionSystem.highlight(filtered)
		end

		-- Трекинг статистики
		StatsSystem.increment("messagesSent")

		-- Добавление в историю
		HistorySystem.add({
			sender = player.Name,
			text   = text,
			type   = "outgoing",
		})

		-- Звук при отправке
		if Config.Current.notifications.soundEnabled then
			SoundSystem.play("messageSent")
		end

		HooksSystem.fire("messageSent", text)

		return processed
	end)
end

ChatSystem.MessageHandler = MessageHandler

--------------------------------------------------------------------------------
-- 🎮 СЕКЦИЯ 22: ОБРАБОТКА ВВОДА (INPUT HANDLER)
--------------------------------------------------------------------------------
local InputHandler = {}

function InputHandler.setup()
	-- Обработка нажатий клавиш
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- F1 — показать помощь
		if input.KeyCode == Enum.KeyCode.F1 then
			CommandSystem.execute("/help")
		end

		-- F2 — показать статистику
		if input.KeyCode == Enum.KeyCode.F2 then
			CommandSystem.execute("/stats")
		end
	end)
end

ChatSystem.InputHandler = InputHandler

--------------------------------------------------------------------------------
-- 🔄 СЕКЦИЯ 23: ПЕРИОДИЧЕСКИЕ ЗАДАЧИ (PERIODIC TASKS)
--------------------------------------------------------------------------------
local PeriodicTasks = {}

function PeriodicTasks.start()
	-- Автоочистка старых уведомлений
	task.spawn(function()
		while true do
			task.wait(60)
			-- Очистка пустых записей из очереди
			local newQueue = {}
			for _, gui in ipairs(NotificationSystem.queue) do
				if gui and gui.Parent then
					table.insert(newQueue, gui)
				end
			end
			NotificationSystem.queue = newQueue
		end
	end)

	-- Автообновление индикатора при смене персонажа
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head")
		if Config.Current.typingIndicator.enabled then
			TypingIndicatorModule.destroy()
			TypingIndicatorModule.setup()
		end
	end)
end

ChatSystem.PeriodicTasks = PeriodicTasks

--------------------------------------------------------------------------------
-- 🚀 СЕКЦИЯ 24: ГЛАВНАЯ ИНИЦИАЛИЗАЦИЯ (MAIN INITIALIZATION)
--------------------------------------------------------------------------------
local function initialize()
	Utils.info("═══════════════════════════════════════════════════════")
	Utils.info("🍎 APPLE GLASSMORPHISM CHAT SYSTEM — ULTIMATE EDITION")
	Utils.info("   Версия: " .. ChatSystem.Version)
	Utils.info("═══════════════════════════════════════════════════════")

	-- Инициализация модулей в правильном порядке
	Utils.safeCall(function()
		-- 1. Базовая настройка чата
		ChatWindowModule.setup()
		BubbleChatModule.setup()
		ChatInputModule.setup()

		-- 2. Индикатор печати
		if Config.Current.typingIndicator.enabled then
			TypingIndicatorModule.setup()
		end

		-- 3. Обработчики ввода
		InputHandler.setup()

		-- 4. Периодические задачи
		PeriodicTasks.start()

		-- 5. Приветственное уведомление
		task.delay(1, function()
			ChatSystem.Notifications.success(
				"✨ Система активирована",
				"Apple Glassmorphism v" .. ChatSystem.Version .. " • /help для команд"
			)
		end)

		Utils.info("✅ Все модули успешно инициализированы")
		Utils.info("📋 Команд: " .. tostring(#CommandSystem.getList()))
		Utils.info("🎨 Тем: " .. tostring(#Themes.getList()))
		Utils.info("😊 Эмодзи: " .. tostring(#EmojiSystem.getList()))
	end)

	Utils.info("═══════════════════════════════════════════════════════")
	Utils.info("✨ Система готова к работе!")
	Utils.info("═══════════════════════════════════════════════════════")
end

-- Запуск инициализации
initialize()

--------------------------------------------------------------------------------
-- 📦 СЕКЦИЯ 25: ЭКСПОРТ ГЛОБАЛЬНОГО ОБЪЕКТА
--------------------------------------------------------------------------------
_G.ChatSystem = ChatSystem

return ChatSystem