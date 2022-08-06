CREATE TABLE programmer_series_map (
    programmer_id INT NOT NULL,
    ordering INT,
    series_id INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (programmer_id)
        REFERENCES programmers(programmer_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (series_id)
        REFERENCES series(series_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (programmer_id, series_id)
);
