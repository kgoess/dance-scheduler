CREATE TABLE band_membership (
    band_id INT NOT NULL,
    talent_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (band_id)
        REFERENCES bands(band_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (talent_id)
        REFERENCES talent(talent_id)
        ON DELETE RESTRICT,

    UNIQUE INDEX band_membership_idx(band_id, talent_id),
    UNIQUE KEY (band_id, ordering)
);
