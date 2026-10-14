"""Build first, then smoke-test a native release using an isolated temporary DB."""
import json, os, pathlib, re, secrets, subprocess, tempfile, time, urllib.request

root = pathlib.Path(__file__).resolve().parent.parent
release = root / '_build/prod/rel/source_cat/bin/source_cat'
with tempfile.TemporaryDirectory(prefix='sourcecat-release-') as directory:
    env = dict(os.environ, PHX_SERVER='true', PHX_HOST='localhost', PORT='18081', POOL_SIZE='1',
               DATABASE_PATH=directory+'/smoke.sqlite', RELEASE_TMP=directory+'/runtime', SECRET_KEY_BASE=secrets.token_hex(64),
               ADMIN_PASSWORD=secrets.token_hex(16), RELEASE_NODE='sourcecat_smoke@127.0.0.1', RELEASE_DISTRIBUTION='none')
    base = 'http://localhost:18081'
    log = open(directory+'/release.log', 'w+')
    process = None
    cookie, token = '', ''
    def start():
        global process
        process = subprocess.Popen([str(release), 'start'], env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        for _ in range(100):
            try:
                with urllib.request.urlopen(base+'/healthz', timeout=1) as response:
                    assert response.status == 200
                return
            except OSError:
                if process.poll() is not None:
                    log.seek(0)
                    raise RuntimeError('Release stopped: '+log.read())
                time.sleep(.2)
        raise RuntimeError('Release health check timed out')
    def stop():
        process.terminate()
        try: process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
    def request(path, body=None):
        global cookie
        headers = {'X-Forwarded-Proto':'https', 'Accept':'*/*'}
        if cookie: headers['Cookie'] = cookie
        if body is not None: headers.update({'Content-Type':'application/json','X-CSRF-Token':token})
        req = urllib.request.Request(base+path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            set_cookie = response.headers.get('Set-Cookie')
            if set_cookie:
                assert 'secure' in set_cookie.lower() and 'httponly' in set_cookie.lower()
                cookie = set_cookie.split(';')[0]
            raw = response.read()
            return json.loads(raw) if 'application/json' in response.headers.get('Content-Type','') else raw.decode()
    try:
        start()
        html = request('/')
        asset = re.search(r'src="([^"]*index[^"]*\.js[^"]*)"', html).group(1)
        assert 'app' in html and len(request(asset)) > 1000
        state = request('/community/session'); token = state['token']
        state = request('/community/signup', {'secret':'123456'})
        assert state['user'] and state['user']['kind'] == 'pin'
        token = state['token']
        q = request('/community/questions', {'title':'Release persistence test', 'topic':'Crash Course', 'body':'A question created in the isolated release database.'})['question']['id']
        request('/community/questions/'+q+'/comments', {'body':'The release supports replies too.'})
        request('/admin/login', {'password':env['ADMIN_PASSWORD']})
        fields = {'id':'release-post','title':'Release article','kind':'article','category':'Crash Course','body':'<h2>Safe</h2><script>bad()</script>','status':'published'}
        saved = request('/admin/save', fields)['post']
        assert '<script' not in saved['body']
        request('/community/bookmarks/release-post', {'saved':'yes'})
        assert request('/community/bookmarks') == ['release-post']
        stop(); start()
        assert request('/community/session')['user']
        assert request('/api/posts')[0]['id'] == 'release-post'
        assert request('/api/questions')[0]['id'] == q
        assert request('/community/questions/'+q+'/comments/1')['total'] == 1
        assert request('/community/bookmarks') == ['release-post']
        print('Production release passed: migrations, assets, secure cookies, CSRF, signup, Studio write, sanitization, question/reply, bookmark, and persistence after restart.')
    finally:
        if process and process.poll() is None: stop()
        log.close()
