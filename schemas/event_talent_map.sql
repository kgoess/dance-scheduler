CREATE TABLE event_talent_map (
    event_id INT NOT NULL,
    talent_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (talent_id)
        REFERENCES talent(talent_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, talent_id),
    UNIQUE KEY (event_id, ordering)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
