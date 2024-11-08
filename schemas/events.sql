CREATE TABLE events (
    event_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    synthetic_name varchar(255),
    start_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_date DATE,
    end_time TIME,
    short_desc VARCHAR(2048),    
    long_desc MEDIUMTEXT,
    custom_url VARCHAR(255),
    photo_url VARCHAR(255),
    custom_pricing TEXT(32866),
    is_series_defaults BOOLEAN NOT NULL DEFAULT 0,
    series_id INT,
    and_friends BOOLEAN NOT NULL DEFAULT 0,
    is_canceled BOOLEAN NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX events_name_idx (name),
    INDEX events_start_time_idx (start_time),
    INDEX events_start_date on events (start_date),
    INDEX events_series_idx (series_id),


    FOREIGN KEY (series_id)
        REFERENCES series(series_id)
      ON DELETE RESTRICT

    -- nope, that only works if is_series_defaults is either 1 or null
    -- UNIQUE KEY (series_id, is_series_defaults)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
