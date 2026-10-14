"""Read a consistent snapshot of the original Glimr database; never write to it."""
import json,sqlite3,sys
from pathlib import Path
with sqlite3.connect(Path(sys.argv[1]).resolve().as_uri()+'?mode=ro',uri=True) as db:
    db.row_factory=sqlite3.Row
    db.execute('BEGIN')
    tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    required={'blog_entries','community_users','community_comments','community_bookmarks','community_questions'}
    if not required.issubset(tables): raise SystemExit('This is not a SourceCat Glimr database.')
    output={t:[dict(r) for r in db.execute('SELECT * FROM '+t)] for t in sorted(required)}
    print(json.dumps(output,ensure_ascii=False))
