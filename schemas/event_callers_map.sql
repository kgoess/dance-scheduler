CREATE TABLE event_callers_map (
    event_id INT NOT NULL,
    caller_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (caller_id)
        REFERENCES callers(caller_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, caller_id),
    UNIQUE KEY (event_id, ordering)

) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
