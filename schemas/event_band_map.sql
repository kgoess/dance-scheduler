CREATE TABLE event_band_map (
    event_id INT NOT NULL,
    band_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (band_id)
        REFERENCES bands(band_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, band_id),
    UNIQUE KEY (event_id, ordering)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
