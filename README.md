# Система обработки архива верфи Соломбала

Автоматизированная система для обработки отсканированных чертежей и документов архива Соломбальской верфи. Система конвертирует исходные файлы, генерирует метаданные, создает миниатюры и публикует контент для веб-сайта.

## Описание проекта

Этот репозиторий содержит PowerShell скрипты для:
- Обработки отсканированных PDF и TIFF файлов
- Автоматического извлечения метаданных из имен файлов
- Генерации контента для статического сайта на базе Zola
- Управления версиями метаданных через Git
- Создания merge request'ов в GitLab

### Основные возможности

- **Автоматическая обработка**: Конвертация PDF в TIFF, оптимизация изображений
- **Генерация метаданных**: Извлечение тегов, дат и другой информации из имен файлов
- **Создание миниатюр**: Автоматическая генерация превью изображений
- **Веб-контент**: Генерация контента для статического сайта
- **Контроль версий**: Отслеживание изменений через Git
- **Безопасное хеширование**: Использование MD5 для индексирования файлов
- **Кроссплатформенность**: Поддержка Windows, macOS и Linux

## Быстрый старт

### Системные требования

- **PowerShell 7+** (Windows, macOS, Linux)
- **Git** для управления версиями метаданных
- **ImageMagick** для обработки изображений

### Установка

1. **Клонирование репозитория**:
```bash
git clone <repository-url>
cd generationscript
```

2. **Настройка конфигурации**:
Отредактируйте `config.json`:
```json
{
  "SourcePath": "/path/to/scanned/files",
  "ResultPath": "/path/to/results",
  "ZolaContentPath": "/path/to/site/content",
  "GitRepoUrl": "git@gitlab.com:solombala-archive/metadata.git",
  "GitlabProjectId": "your-project-id"
}
```

## Использование

### Основной скрипт обработки

```powershell
# Полная обработка архива
./Complete-ArchiveProcess.ps1

# Обработка с подробным выводом
./Complete-ArchiveProcess.ps1 -Verbose
```

### Отдельные операции

```powershell
# Только конвертация файлов
./Convert-ScannedFIles.ps1 -SourcePath "путь/к/исходникам" -ResultPath "путь/к/результатам"

# Только генерация контента для сайта
./ConvertTo-ZolaContent.ps1 -MetadataPath "путь/к/метаданным" -ZolaContentPath "путь/к/контенту"
```

### Тестирование

```powershell
# Запуск всех тестов
Invoke-Pester ./tests/

# Запуск конкретного теста
Invoke-Pester ./tests/HashHelper.Tests.ps1
```

## Архитектура системы

### Основные скрипты

- `Complete-ArchiveProcess.ps1` - Главный скрипт обработки
- `Convert-ScannedFIles.ps1` - Конвертация и обработка файлов
- `ConvertTo-ZolaContent.ps1` - Генерация контента для Zola
- `Sync-MetadataGitRepo.ps1` - Синхронизация Git репозитория
- `Submit-MetadataToRemote.ps1` - Отправка изменений в удаленный репозиторий

### Библиотеки (libs/)

- `HashHelper.psm1` - Работа с MD5 хешами
- `PathHelper.psm1` - Обработка путей (поддержка UNC сетевых путей)
- `ConvertImage.psm1` - Конвертация и оптимизация изображений
- `GitHelper.psm1` - Операции с Git
- `ZolaContentHelper.psm1` - Генерация контента для Zola
- `ToolsHelper.psm1` - Вспомогательные утилиты

## Настройки системы

### Git репозиторий

Адрес репозитория для хранения метаданных: [solombala-archive/metadata](https://gitlab.com/solombala-archive/metadata)

##### Настройка доступа

1. Создать аккаунт на gitlab.com
2. Создать ssh ключ для пользователя
```ssh-keygen -f ~/.ssh/solombala-gitlab -t ed25519 -C "Key for solombala archive"```
3. добавить ключ и имя пользователя в `.ssh/config` файл
    ```
    #GitLab.com
    Host gitlab.com
	    User akrivopolenov
  	    PreferredAuthentications publickey
  	    IdentityFile ~/.ssh/solombala-gitlab
    ```
4. Загрузить ключ в аккаунт gitlab.com
5. Проверить, что ключ работает: `ssh -T git@gitlab.com`

##### Репозиторий в папке metadata

Если папки `metadata` не существует в папке с результатами обработки, то можно ее скачать с внешнего репозитория:

`git checkout git@gitlab.com:solombala-archive/metadata.git`

Если папка `metadata` существует, нужно проверить, есть ли в ней git и есть ли ссылка на внешний репозиторий

```
ls -al | grep  .git
drwxr-xr-x@ 9 akrivopolenov  staff    288 Jun  7 21:45 .git
```
если пусто, то:
```
git init
git remote add origin git@gitlab.com:solombala-archive/metadata
git switch main
git branch --set-upstream-to=origin/main main
```

## Особенности реализации

### MD5 хеширование
Система использует MD5 хеширование для:
- Создания уникальных идентификаторов файлов
- Индексирования файлов по парам директория+имя файла
- Кроссплатформенной совместимости

### Поддержка сетевых путей
Поддерживаются UNC пути Windows:
```
\\server\share\path\to\files
\\192.168.1.100\archive\scans
```

### Автоматическая установка зависимостей
Система использует встроенные возможности PowerShell:
- MD5 хеширование через Get-FileHash
- Определение доступных пакетных менеджеров для других инструментов
- Graceful fallback при ошибках установки

## Разработка и тестирование

### Запуск тестов
```powershell
# Все тесты
Invoke-Pester ./tests/

# Конкретная функциональность
Invoke-Pester ./tests/HashHelper.Tests.ps1 -Verbose
```

### CI/CD
Проект использует GitHub Actions для:
- Автоматического запуска тестов
- Проверки на Windows, macOS, Linux
- Автоматической установки зависимостей

### Отладка
Используйте флаг `-Verbose` для подробного вывода:
```powershell
$VerbosePreference = "Continue"
./Complete-ArchiveProcess.ps1
```

## Поддержка и документация

### Документация разработчика
Подробная техническая документация в `CLAUDE.md`

### Сообщение об ошибках
1. Проверьте логи с флагом `-Verbose`
2. Убедитесь в правильности конфигурации `config.json`
3. Проверьте доступность Git репозитория

### Контакты
- Владелец репозитория: akrivopolenov@gmail.com
- Проект: Архив Соломбальской верфи
