INSERT INTO weaver.data_source (name, url)
VALUES ('USGS Mineral Resources Data System', 'https://mrdata.usgs.gov/mrds/')
ON CONFLICT (name) DO NOTHING;
