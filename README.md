# development

#### Техническое задание: необходимо разработать мобильное приложение, позволяющее отслеживать прогресс процесса стройки. Реализовать систему ролей. 
---
#### Роль руководителя: создавать этапы стройки, с указанием материальных и нематериальных ресурсов, списки рабочих, списки работ на разных этапах, технические документации и комментарии, приостанавливать/возобновлять каждый этап, архивировать проект, осуществлять поиск проекта по различным критериям. 
---
#### Роль работника: корректировать сроки выполнения работ, изменять статус работ, вносить комментарии. 
---
#### Роль заказчика: просмотр информации о проекте, подтверждение внесения правок проекта, получение уведомлений о сроках выполнения проекта.
---
#### Администратору необходимо организовать ведение базы данных. Предусмотреть реализацию в приложении чата между участниками проекта.			
---
структура БД в качестве JSON
```json
[
  {
    "table_name": "comments",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "comments",
    "column_name": "entity_type",
    "data_type": "USER-DEFINED",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "comments",
    "column_name": "entity_id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "comments",
    "column_name": "user_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "comments",
    "column_name": "text",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "comments",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "messages",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "messages",
    "column_name": "project_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "messages",
    "column_name": "sender_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "messages",
    "column_name": "receiver_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "messages",
    "column_name": "text",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "messages",
    "column_name": "is_notification",
    "data_type": "boolean",
    "is_nullable": "YES",
    "column_default": "false"
  },
  {
    "table_name": "messages",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "messages",
    "column_name": "read_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "project_participants",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "project_participants",
    "column_name": "project_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "project_participants",
    "column_name": "user_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "project_participants",
    "column_name": "role",
    "data_type": "USER-DEFINED",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "project_participants",
    "column_name": "joined_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "projects",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "projects",
    "column_name": "name",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "projects",
    "column_name": "description",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "projects",
    "column_name": "start_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "projects",
    "column_name": "end_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "projects",
    "column_name": "status",
    "data_type": "USER-DEFINED",
    "is_nullable": "YES",
    "column_default": "'active'::project_status"
  },
  {
    "table_name": "projects",
    "column_name": "created_by",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "projects",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "projects",
    "column_name": "updated_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "stages",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "stages",
    "column_name": "project_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "name",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "description",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "start_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "end_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "status",
    "data_type": "USER-DEFINED",
    "is_nullable": "YES",
    "column_default": "'planned'::stage_status"
  },
  {
    "table_name": "stages",
    "column_name": "material_resources",
    "data_type": "jsonb",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "non_material_resources",
    "data_type": "jsonb",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "stages",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "stages",
    "column_name": "updated_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "technical_documents",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "technical_documents",
    "column_name": "project_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "technical_documents",
    "column_name": "name",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "technical_documents",
    "column_name": "file_url",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "technical_documents",
    "column_name": "description",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "technical_documents",
    "column_name": "uploaded_by",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "technical_documents",
    "column_name": "uploaded_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "users",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "users",
    "column_name": "email",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "users",
    "column_name": "full_name",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "users",
    "column_name": "phone",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "users",
    "column_name": "is_admin",
    "data_type": "boolean",
    "is_nullable": "YES",
    "column_default": "false"
  },
  {
    "table_name": "users",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "users",
    "column_name": "primary_role",
    "data_type": "USER-DEFINED",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "id",
    "data_type": "uuid",
    "is_nullable": "NO",
    "column_default": "uuid_generate_v4()"
  },
  {
    "table_name": "works",
    "column_name": "stage_id",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "name",
    "data_type": "text",
    "is_nullable": "NO",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "description",
    "data_type": "text",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "start_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "end_date",
    "data_type": "date",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "status",
    "data_type": "USER-DEFINED",
    "is_nullable": "YES",
    "column_default": "'todo'::work_status"
  },
  {
    "table_name": "works",
    "column_name": "assigned_to",
    "data_type": "uuid",
    "is_nullable": "YES",
    "column_default": null
  },
  {
    "table_name": "works",
    "column_name": "created_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  },
  {
    "table_name": "works",
    "column_name": "updated_at",
    "data_type": "timestamp with time zone",
    "is_nullable": "YES",
    "column_default": "CURRENT_TIMESTAMP"
  }
]
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

Чат 
Групповой чат (может читать и писать)
