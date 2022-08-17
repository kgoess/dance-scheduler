CREATE TABLE programmer_events_map (
    programmer_id INT NOT NULL,
    ordering INT,
    event_id INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (programmer_id)
        REFERENCES programmers(programmer_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (programmer_id, event_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
