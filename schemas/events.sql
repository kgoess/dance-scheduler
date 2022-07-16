CREATE TABLE events (
    event_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256),
    start_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_date DATE,
    end_time TIME,
    short_desc VARCHAR(2048),    
    is_template BOOLEAN,
    series_id INT,
    is_canceled BOOLEAN,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX events_name_idx (name),
    INDEX events_start_time_idx (start_time),
    INDEX events_series_idx (series_id),

    FOREIGN KEY (series_id)
        REFERENCES series(series_id)
      ON DELETE RESTRICT

    -- nope, that only works if is_template is either 1 or null
    -- UNIQUE KEY (series_id, is_template)
);


