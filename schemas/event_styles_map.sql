
CREATE TABLE event_styles_map (
    event_id INT NOT NULL,
    style_id INT NOT NULL,
    ordering INT NOT NULL,

    FOREIGN KEY (event_id)
        REFERENCES events(event_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (style_id)
        REFERENCES styles(style_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (event_id, style_id),
    UNIQUE KEY (event_id, ordering)

);
