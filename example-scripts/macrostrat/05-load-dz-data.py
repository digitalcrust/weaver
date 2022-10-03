from pathlib import Path
from rich import print

sql = Path(__file__).parent / "procedures" / "unreferenced-dz-samples.sql"

res = weaver_db.exec_sql_query(sql)

for row in res:
    print(dict(row))
