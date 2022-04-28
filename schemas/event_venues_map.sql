CREATE TABLE event_venues_map (
    event_id INT NOT NULL,
    venue_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (venue_id)
        REFERENCES venues(venue_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, venue_id),
    UNIQUE KEY (event_id, ordering)

);
