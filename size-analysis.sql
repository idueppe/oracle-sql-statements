
-- Total Size of the current tablespace

SELECT round(sum(bytes)/1024/1024/1024,2) as TOTAL_SIZE_IN_GB FROM user_segments;

SELECT 
  TABLESPACE_NAME, 
  round(sum(bytes)/1024/1024/1024,2) as TOTAL_SIZE_IN_GB 
FROM 
  user_segments
GROUP BY 
  TABLESPACE_NAME;


-- A monthly cluster of all data within a table
-- The SQL needs a timestamp column when the row was created

SELECT
	month, 
	anzahl, 
	sum(anzahl) over (order by monat) kumuliert
FROM
	(SELECT monat, count(monat) as anzahl FROM
	(SELECT to_char(creationDate,'YY MM') as monat FROM {TABLENAME})
WHERE 
	not monat is null
GROUP BY 
	monat
HAVING 
	count(monat) > 1
ORDER BY 
	monat ASC);


-- Analyse the size of all table within the current user tablespace.
-- The size contains the size of the table, assigned indexes, and lobsegments.
-- The result also contains the totalsize in gigabytes and bytes and the oversize 
-- The result is ordered by decreasing totalsize of the tables
.
SELECT
	r.TABLE_NAME,
	round (TOTALSIZE / 1024 / 1024 / 1024, 2) TOTALSIZE_GB,
	round (OVERSIZE / 1024 / 1024 / 1024, 2) OVERSIZE_GB,
	round (TOTAlSIZE / r.ROW_NUMBERS,0) BYTES_PER_ROW,
	r.TOTALSIZE,
	r.ROW_NUMBERS
FROM
	(
	 	SELECT
			t.*, 
			(SELECT NUM_ROWS FROM user_tables ut WHERE ut.TABLE_NAME = t.TABLE_NAME) AS ROW_NUMBERS
		FROM
			(
				SELECT
					TABLE_NAME,
					TOTALSIZE,
					SUM(TOTALSIZE) OVER (ORDER BY TOTALSIZE DESC) OVERSIZE
				FROM
					(
						SELECT
							TABLE_NAME,
							SUM(SIZE_BYTES) AS TOTALSIZE
						FROM
							(
								SELECT
									s.SEGMENT_NAME 		AS TABLE_NAME,
									i.INDEX_NAME 		AS OBJECT_NAME,
									seg.SEGMENT_TYPE	AS OBJECT_TYPE,
									seg.BYTES 			AS SIZE_BYTES
								FROM
									user_segments s
									RIGHT JOIN user_indexes i on i.TABLE_NAME = s.SEGMENT_NAME 
									LEFT JOIN user_segments seg on seg.SEGMENT_NAME = i.INDEX_NAME
							UNION
								SELECT
									s.SEGMENT_NAME 		AS TABLE_NAME,
									l.SEGMENT_NAME 		AS OBJECT_NAME,
									seg.SEGMENT_TYPE	AS OBJECT_TYPE,
									seg.BYTES 			AS SIZE_BYTES
								FROM
									user_segments s
									RIGHT JOIN user_lobs l on l.TABLE_NAME = s.SEGMENT_NAME 
									LEFT JOIN user_segments seg on seg.SEGMENT_NAME = l.SEGMENT_NAME
							UNION
								SELECT
									s.SEGMENT_NAME 		AS TABLE_NAME,
									s.SEGMENT_NAME 		AS OBJECT_NAME,
									s.SEGMENT_TYPE 		AS OBJECT_TYPE,
									s.BYTES 			AS SIZE_BYTES
								FROM
									user_segments s
								WHERE
									s.SEGMENT_TYPE = 'TABLE'
							)
						GROUP BY 
							TABLE_NAME
						HAVING
							SUM(SIZE_BYTES) > 0
						ORDER BY 
							TOTALSIZE DESC
					)
			)  t
	) r 
WHERE 
	r.ROW_NUMBERS > 0;