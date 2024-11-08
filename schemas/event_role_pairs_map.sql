CREATE TABLE event_role_pairs_map (
    event_id INT NOT NULL,
    role_pair_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (role_pair_id)
        REFERENCES role_pairs(role_pair_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, role_pair_id),
    UNIQUE KEY (event_id, ordering)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
