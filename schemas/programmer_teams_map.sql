CREATE TABLE programmer_teams_map (
    programmer_id INT NOT NULL,
    ordering INT,
    team_id INT NOT NULL,
    created_ts DATETIME NOT NULL,
    modified_ts TIMESTAMP NOT NULL,

    FOREIGN KEY (programmer_id)
        REFERENCES programmers(programmer_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (team_id)
        REFERENCES teams(team_id)
        ON DELETE RESTRICT,

    UNIQUE KEY (programmer_id, team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
