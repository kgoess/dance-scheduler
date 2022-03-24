
-- e.g. SERIES, CAMP
CREATE TABLE event_types (
    event_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(16),
    UNIQUE INDEX event_types_name_idx (name)
);
