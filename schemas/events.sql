CREATE TABLE events (
    event_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256),
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    is_camp BOOLEAN,
    long_desc VARCHAR(32766),
    short_desc VARCHAR(1024),    
    is_template BOOLEAN,
    series_id INT,
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX events_name_idx (name),
    INDEX events_start_time_idx (start_time),
    INDEX events_series_idx (series_id),

    FOREIGN KEY (series_id)
        REFERENCES series(series_id)
      ON DELETE RESTRICT,


    UNIQUE KEY (series_id, is_template)
);


