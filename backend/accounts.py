"""Accounts: sign up / sign in with email + password, and token checks.

- Accounts live in backend/data/accounts.db (SQLite, not in git).
- Passwords are stored only as salted hashes (werkzeug / scrypt), never in plain text.
- Signing in returns a random token. The app sends it as
  "Authorization: Bearer <token>" and the photo/outfit endpoints reject
  requests without a valid one (see require_auth).
- A demo account is created on startup if it doesn't exist
  (email/password from WARDROBE_DEMO_EMAIL / WARDROBE_DEMO_PASSWORD).
"""

import os
import re
import secrets
import sqlite3
from datetime import datetime, timezone
from functools import wraps

from flask import Blueprint, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

DB_PATH = os.environ.get(
    'WARDROBE_ACCOUNTS_DB', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'accounts.db'))
DEMO_EMAIL = os.environ.get('WARDROBE_DEMO_EMAIL', 'demo@wardrobeplus.app')
DEMO_PASSWORD = os.environ.get('WARDROBE_DEMO_PASSWORD', 'demo1234')
MIN_PASSWORD = 6
EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')

bp = Blueprint('accounts', __name__)


def _connect():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with _connect() as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL)''')
        conn.execute('''CREATE TABLE IF NOT EXISTS sessions (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id),
            created_at TEXT NOT NULL)''')


def normalize_email(email):
    return (email or '').strip().lower()


def create_user(email, password, name):
    email = normalize_email(email)
    with _connect() as conn:
        cur = conn.execute(
            'INSERT INTO users (email, name, password_hash, created_at) VALUES (?, ?, ?, ?)',
            (email, name.strip(), generate_password_hash(password), datetime.now(timezone.utc).isoformat()))
        return cur.lastrowid


def ensure_demo_account():
    with _connect() as conn:
        exists = conn.execute('SELECT 1 FROM users WHERE email = ?', (normalize_email(DEMO_EMAIL),)).fetchone()
    if not exists:
        create_user(DEMO_EMAIL, DEMO_PASSWORD, 'Demo')


def _public(user):
    return {'id': user['id'], 'email': user['email'], 'name': user['name'], 'created_at': user['created_at']}


def _new_session(user_id):
    token = secrets.token_urlsafe(32)
    with _connect() as conn:
        conn.execute('INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)',
                     (token, user_id, datetime.now(timezone.utc).isoformat()))
    return token


def _error(code, message, status):
    return jsonify({'error': code, 'message': message}), status


def user_for_token(token):
    if not token:
        return None
    with _connect() as conn:
        return conn.execute(
            'SELECT users.* FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.token = ?',
            (token,)).fetchone()


def _bearer():
    header = request.headers.get('Authorization', '')
    return header[7:].strip() if header.lower().startswith('bearer ') else None


def require_auth(view):
    """Endpoint decorator: 401 unless a valid sign-in token is sent."""
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = user_for_token(_bearer())
        if user is None:
            return _error('unauthorized', 'Please sign in again.', 401)
        g.user = user
        return view(*args, **kwargs)
    return wrapped


@bp.route('/auth/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    email, password, name = normalize_email(data.get('email')), data.get('password') or '', (data.get('name') or '').strip()
    if not EMAIL_RE.match(email):
        return _error('bad_email', 'Enter a valid email address.', 400)
    if len(password) < MIN_PASSWORD:
        return _error('weak_password', f'Password must be at least {MIN_PASSWORD} characters.', 400)
    if not name:
        return _error('no_name', 'Enter your name.', 400)
    try:
        user_id = create_user(email, password, name)
    except sqlite3.IntegrityError:
        return _error('email_taken', 'An account with this email already exists. Sign in instead.', 409)
    with _connect() as conn:
        user = conn.execute('SELECT * FROM users WHERE id = ?', (user_id,)).fetchone()
    return jsonify({'token': _new_session(user_id), 'user': _public(user)}), 201


@bp.route('/auth/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    email, password = normalize_email(data.get('email')), data.get('password') or ''
    with _connect() as conn:
        user = conn.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
    if user is None or not check_password_hash(user['password_hash'], password):
        return _error('bad_credentials', 'Wrong email or password.', 401)
    return jsonify({'token': _new_session(user['id']), 'user': _public(user)})


@bp.route('/auth/me', methods=['GET'])
@require_auth
def me():
    return jsonify({'user': _public(g.user)})


@bp.route('/auth/logout', methods=['POST'])
def logout():
    token = _bearer()
    if token:
        with _connect() as conn:
            conn.execute('DELETE FROM sessions WHERE token = ?', (token,))
    return jsonify({'ok': True})
