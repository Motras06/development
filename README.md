# development

Техническое задание: необходимо разработать мобильное приложение, позволяющее отслеживать прогресс процесса стройки. Реализовать систему ролей. 
---
Роль руководителя: создавать этапы стройки, с указанием материальных и нематериальных ресурсов, списки рабочих, списки работ на разных этапах, технические документации и комментарии, приостанавливать/возобновлять каждый этап, архивировать проект, осуществлять поиск проекта по различным критериям. 
---
Роль работника: корректировать сроки выполнения работ, изменять статус работ, вносить комментарии. 
---
Роль заказчика: просмотр информации о проекте, подтверждение внесения правок проекта, получение уведомлений о сроках выполнения проекта.
---
Администратору необходимо организовать ведение базы данных. Предусмотреть реализацию в приложении чата между участниками проекта.			

структура БД в качестве JSON
```json
{
  "database_structure": {
    "enums": {
      "project_status": ["active", "paused", "archived", "completed"],
      "participant_role": ["leader", "worker", "client"],
      "stage_status": ["planned", "in_progress", "paused", "completed"],
      "work_status": ["todo", "in_progress", "done", "delayed"],
      "comment_entity_type": ["project", "stage", "work"]
    },
    "tables": {
      "users": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "email": { "type": "TEXT", "unique": true, "not_null": true },
          "full_name": { "type": "TEXT" },
          "phone": { "type": "TEXT" },
          "is_admin": { "type": "BOOLEAN", "default": false },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": ["email"]
      },
      "projects": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "name": { "type": "TEXT", "not_null": true },
          "description": { "type": "TEXT" },
          "start_date": { "type": "DATE" },
          "end_date": { "type": "DATE" },
          "status": { "type": "project_status", "default": "active" },
          "created_by": { "type": "UUID", "references": "users(id)", "on_delete": "SET NULL" },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" },
          "updated_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": ["name", "status", "start_date", "end_date", "created_by"]
      },
      "project_participants": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "project_id": { "type": "UUID", "references": "projects(id)", "on_delete": "CASCADE" },
          "user_id": { "type": "UUID", "references": "users(id)", "on_delete": "CASCADE" },
          "role": { "type": "participant_role", "not_null": true },
          "joined_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "constraints": [{ "unique": ["project_id", "user_id"] }],
        "indexes": ["project_id", "user_id", "role"]
      },
      "stages": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "project_id": { "type": "UUID", "references": "projects(id)", "on_delete": "CASCADE" },
          "name": { "type": "TEXT", "not_null": true },
          "description": { "type": "TEXT" },
          "start_date": { "type": "DATE" },
          "end_date": { "type": "DATE" },
          "status": { "type": "stage_status", "default": "planned" },
          "material_resources": { "type": "JSONB" },
          "non_material_resources": { "type": "JSONB" },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" },
          "updated_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": ["project_id", "status", "start_date", "end_date"]
      },
      "works": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "stage_id": { "type": "UUID", "references": "stages(id)", "on_delete": "CASCADE" },
          "name": { "type": "TEXT", "not_null": true },
          "description": { "type": "TEXT" },
          "start_date": { "type": "DATE" },
          "end_date": { "type": "DATE" },
          "status": { "type": "work_status", "default": "todo" },
          "assigned_to": { "type": "UUID", "references": "users(id)", "on_delete": "SET NULL" },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" },
          "updated_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": ["stage_id", "status", "assigned_to", "start_date", "end_date"]
      },
      "technical_documents": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "project_id": { "type": "UUID", "references": "projects(id)", "on_delete": "CASCADE" },
          "name": { "type": "TEXT", "not_null": true },
          "file_url": { "type": "TEXT" },
          "description": { "type": "TEXT" },
          "uploaded_by": { "type": "UUID", "references": "users(id)", "on_delete": "SET NULL" },
          "uploaded_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": ["project_id"]
      },
      "comments": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "entity_type": { "type": "comment_entity_type", "not_null": true },
          "entity_id": { "type": "UUID", "not_null": true },
          "user_id": { "type": "UUID", "references": "users(id)", "on_delete": "CASCADE" },
          "text": { "type": "TEXT", "not_null": true },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" }
        },
        "indexes": [["entity_type", "entity_id"], "user_id"]
      },
      "messages": {
        "columns": {
          "id": { "type": "UUID", "primary_key": true, "default": "uuid_generate_v4()" },
          "project_id": { "type": "UUID", "references": "projects(id)", "on_delete": "CASCADE" },
          "sender_id": { "type": "UUID", "references": "users(id)", "on_delete": "CASCADE" },
          "receiver_id": { "type": "UUID", "references": "users(id)", "on_delete": "SET NULL" },
          "text": { "type": "TEXT", "not_null": true },
          "is_notification": { "type": "BOOLEAN", "default": false },
          "created_at": { "type": "TIMESTAMP WITH TIME ZONE", "default": "CURRENT_TIMESTAMP" },
          "read_at": { "type": "TIMESTAMP WITH TIME ZONE" }
        },
        "indexes": ["project_id", "sender_id", "receiver_id", "created_at"]
      }
    }
  }
}
```

## предпологаемая структура

1. Роль: Руководитель (leader)
Руководитель — самая функциональная роль, ему нужно управлять всем проектом.
Bottom Tabs (5 вкладок):

Проекты
Список всех проектов (активные, приостановленные, архивные)
Кнопка создания нового проекта
Поиск и фильтры по статусу, датам, названию
Карточка проекта с краткой информацией (прогресс, сроки)

Этапы
Список этапов текущего выбранного проекта
Возможность создавать/редактировать/приостанавливать этапы
Добавление ресурсов (материальных и нематериальных)
Просмотр прогресса по этапам (процент выполнения на основе работ)

Работы
Древовидный или плоский список всех работ по этапам
Создание, редактирование, назначение на работников
Изменение статусов и сроков
Фильтр по статусу, просроченным, назначенным

Команда
Список участников проекта (с ролями)
Приглашение новых участников (работников, заказчиков)
Изменение ролей (если нужно)
Просмотр контактов

Чат & Документы
Чат проекта (групповой + личные переписки)
Список технической документации
Загрузка новых документов
Уведомления и комментарии ко всему проекту


2. Роль: Работник (worker)
Работнику нужно видеть только то, что касается его задач, и иметь возможность отчитываться.
Bottom Tabs (4 вкладки):

Мои проекты
Список проектов, в которых он участвует
Краткая информация: название, этап, общий прогресс
Уведомления о новых назначениях

Мои задачи
Основной экран: список всех назначенных на него работ
Фильтры: по статусу, по этапам, просроченные
Возможность менять статус (todo → in_progress → done)
Корректировка сроков (с комментарием)
Добавление комментариев к задаче

Этапы
Просмотр всех этапов проекта (только чтение или с комментариями)
Видит ресурсы, описание этапа
Может оставлять комментарии к этапу

Чат
Групповой чат проекта
Личные переписки с руководителем и другими работниками
Уведомления о сообщениях и изменениях в задачах


3. Роль: Заказчик (client)
Заказчику — максимум прозрачности, минимум управления.
Bottom Tabs (4 вкладки):

Мои проекты
Список проектов, где он заказчик (обычно 1–несколько)
Общая информация: название, сроки, текущий статус
Прогресс-бар общего выполнения

Прогресс
Визуальный дашборд:
– Гант-диаграмма или timeline этапов
– Процент выполнения по этапам и работам
– Просроченные задачи (выделены красным)
– Ключевые даты

Документы
Полный список технической документации
Просмотр и скачивание файлов
История загрузок (кто и когда добавил)

4. Чат 
Групповой чат (может читать и писать)
