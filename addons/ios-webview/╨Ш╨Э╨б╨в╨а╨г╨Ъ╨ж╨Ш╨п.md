

## Как поставить

1. Кинуть папку `addons/ios-webview/` в свой проект
2. В Godot: Project → Settings → Autoload → добавить `res://addons/ios-webview/webview.gd` с именем `WebView`


## Как пользоваться

```gdscript
# Открыть страницу
WebView.open("https://example.com")

# С настройками
WebView.open("https://example.com", {
    "close_delay": 5,         # кнопка ✕ появится через 5 сек
    "auto_dismiss": 30,       # закроется само через 30 сек
    "fullscreen": true,       # на весь экран
    "show_loading": true,     # крутилка пока грузит
})


# Закрыть
WebView.close()

# Проверить открыт ли
if WebView.is_open():
    pass
```

## Сигналы

```gdscript
WebView.opened.connect(func(): print("открылся"))
WebView.closed.connect(func(): print("закрылся"))
WebView.error.connect(func(msg): print("ошибка: ", msg))
```

## Что можно настроить

- close_delay — через сколько секунд покажется крестик (0 = сразу видно)
- auto_dismiss — закроется само через N секунд (0 = не закрывать)
- fullscreen — true = на весь экран, false = окошком
- position — где окошко: center, top, bottom (только если не fullscreen)
- size — размер окошка как доля экрана, например Vector2(0.9, 0.7) это 90% ширины и 70% высоты
- background_color — цвет фона, по умолчанию чёрный
- show_loading — показывать крутилку пока страница грузится

## Сборка для iOS

```bash
# 1. Экспорт. Просто экспорт проекта в годот или через терминал
godot --headless --export-debug "iOS" build/ios/Game.xcodeproj

# 2. Инжект
bash addons/ios-webview/ios/inject.sh build/ios/Game.xcodeproj

# 3. Xcode → Run на айфоне
```

## Авто-открытие при запуске (без кода)

В файле `WebViewBridge.swift` поменять:

```swift
static let autoOpenURL: String? = "https://example.com"
static let autoOpenDelay: TimeInterval = 2.0
```


