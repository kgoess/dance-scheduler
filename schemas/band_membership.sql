
CREATE TABLE band_membership (
    band_id INT NOT NULL,
    talent_id INT NOT NULL,

    UNIQUE INDEX band_membership_idx(band_id, talent_id)
);
