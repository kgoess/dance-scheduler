CREATE TABLE series (
    series_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256),
    frequency VARCHAR(128),
    default_style_id INT,
    default_venue_id INT,
    default_parent_org_id INT,
    default_start_time TIME,
    default_end_time TIME,
    display_notes TEXT(32866),
    programmer_notes TEXT(32866),
    is_deleted BOOLEAN,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    INDEX series_name_idx (name),

    FOREIGN KEY (default_style_id)
        REFERENCES styles(style_id)
        ON DELETE RESTRICT
);
