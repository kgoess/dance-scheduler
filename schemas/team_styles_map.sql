CREATE TABLE team_styles_map (
    team_id INT NOT NULL,
    style_id INT NOT NULL,
    ordering INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (team_id)
        REFERENCES teams(team_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (style_id)
        REFERENCES styles(style_id)
        ON DELETE RESTRICT,

    UNIQUE INDEX team_styles_map_idx(team_id, style_id),
    UNIQUE KEY (team_id, ordering)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
