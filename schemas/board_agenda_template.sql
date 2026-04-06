CREATE TABLE board_agenda_template (
    board_agenda_template_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    agenda_text              TEXT NOT NULL DEFAULT '',
    zoom_url                 VARCHAR(512) NOT NULL DEFAULT '',
    modified_ts              TIMESTAMP NOT NULL,
    created_ts               DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed with the initial template
INSERT INTO board_agenda_template
    (agenda_text, zoom_url, created_ts, modified_ts)
VALUES (
'BACDS Board Meeting
Date: [MEETING DATE]
Time: 7:30 PM
Zoom: [ZOOM LINK]

AGENDA

1. Approval of minutes
2. Action item Review
3. President\'s Report
4. Chair Report
5. Committee reports:
5(a). Fincom/Treasurer\'s report
5(b). Membership
6. Old business
7. New business
8. Adjourn',
    '',
    NOW(),
    NOW()
);
