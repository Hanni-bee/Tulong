# Tulong Database – ERD (Entity Relationship Diagram)

## Database: tulong_offline.db

```mermaid
erDiagram
    users ||--o{ messages : "sender"
    users ||--o{ emergency_alerts : "creator"
    sync_queue }o..o{ users : "references"
    sync_queue }o..o{ messages : "references"
    sync_queue }o..o{ emergency_alerts : "references"

    users {
        string uid PK "PRIMARY KEY"
        int id "legacy row id"
        string firebase_uid UK "UNIQUE"
        string first_name "NOT NULL"
        string last_name "NOT NULL"
        string username UK "NOT NULL UNIQUE"
        string street
        string region
        string province
        string city
        string barangay
        string emergency_message
        string password
        int is_online "DEFAULT 0"
        string account_status "DEFAULT active"
        int created_at "NOT NULL"
        int last_seen
        int is_synced "DEFAULT 0"
        int sync_timestamp
        int address_setup_completed "DEFAULT 0"
        int is_verified "DEFAULT 0"
        int profile_update_count "DEFAULT 0"
        int sos_message_update_count "DEFAULT 0"
        string suffix
    }

    messages {
        int id PK "PRIMARY KEY AUTOINCREMENT"
        string firebase_key
        string chat_id "NOT NULL"
        string message "NOT NULL"
        string sender_id FK "NOT NULL -> users.uid"
        string sender_name "NOT NULL"
        int timestamp "NOT NULL"
        string message_type "DEFAULT text"
        string image_url
        int is_synced "DEFAULT 0"
        int sync_timestamp
        int channel "NOT NULL DEFAULT 1"
        string voice_file_path
        string type "NOT NULL DEFAULT text"
        string severity_level
        string emergency_type
        int is_pinned "DEFAULT 0"
    }

    emergency_alerts {
        int id PK "PRIMARY KEY AUTOINCREMENT"
        string firebase_key
        string message "NOT NULL"
        string location "NOT NULL"
        string user_id FK "NOT NULL -> users.uid"
        int timestamp "NOT NULL"
        string status "DEFAULT active"
        int is_synced "DEFAULT 0"
        int sync_timestamp
    }

    sync_queue {
        int id PK "PRIMARY KEY AUTOINCREMENT"
        string table_name "NOT NULL"
        string record_id "NOT NULL"
        string operation "NOT NULL"
        string data "NOT NULL JSON"
        int created_at "NOT NULL"
        int retry_count "DEFAULT 0"
        int last_attempt
    }
```

---

## Database: detection_history.db (separate DB)

```mermaid
erDiagram
    users ||--o{ detections : "user_uid"

    users {
        string uid PK
    }

    detections {
        int id PK "PRIMARY KEY AUTOINCREMENT"
        string user_uid FK "NOT NULL -> users.uid"
        string emergency_type "NOT NULL"
        string severity "NOT NULL"
        real confidence "NOT NULL"
        int timestamp "NOT NULL"
        string image_path
        int created_at "NOT NULL"
        string failure_reason
        string probability_breakdown "JSON"
    }

    detection_feedback {
        int id PK "PRIMARY KEY AUTOINCREMENT"
        string image_path "NOT NULL"
        int timestamp "NOT NULL"
        int correct "NOT NULL"
        int created_at "NOT NULL"
    }
```

---

## Combined overview (all entities)

```mermaid
erDiagram
    USERS ||--o{ MESSAGES : sends
    USERS ||--o{ EMERGENCY_ALERTS : creates
    USERS ||--o{ DETECTIONS : has
    SYNC_QUEUE }o--|| USERS : table ref
    SYNC_QUEUE }o--|| MESSAGES : table ref
    SYNC_QUEUE }o--|| EMERGENCY_ALERTS : table ref

    USERS {
        string uid PK
        string firebase_uid UK
        string username UK
        string first_name
        string last_name
        int created_at
    }

    MESSAGES {
        int id PK
        string chat_id
        string sender_id FK
        string message
        int timestamp
        int channel
        string type
    }

    EMERGENCY_ALERTS {
        int id PK
        string user_id FK
        string message
        string location
        int timestamp
        string status
    }

    SYNC_QUEUE {
        int id PK
        string table_name
        string record_id
        string operation
        string data
        int created_at
    }

    DETECTIONS {
        int id PK
        string user_uid FK
        string emergency_type
        string severity
        real confidence
        int timestamp
    }

    DETECTION_FEEDBACK {
        int id PK
        string image_path
        int timestamp
        int correct
    }
```

---

## Legend

| Symbol | Meaning |
|--------|--------|
| **PK** | Primary Key |
| **FK** | Foreign Key (logical; not enforced in SQLite DDL) |
| **UK** | Unique |
| `\|\|--o{` | One-to-many (one user, many messages) |
| `}o--\|\|` | Reference (sync_queue references table_name + record_id) |

*Note: `users` in detection_history.db is the same entity (users.uid) but in a different database file.*
